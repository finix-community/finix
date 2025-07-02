#!/usr/bin/env -S tclsh

# This script observes the assertion of
# <network-dataspace ?network ?machine>.
# It reconfigures the kernel IP stack from
# observations of $network using iproute2
# and it asserts the actual configuration
# reported by the kernel into $machine.

package require syndicate
namespace import preserves::*

# Evaluate a body when a named attribute is present.
proc forattr {name attrs body} {
  set items [preserves::project -unpreserve $attrs ". \"$name\""]
  uplevel 1 [list foreach $name $items $body ]
}

proc projectAttr {attrs name} {
  upvar $name val
  preserves::project -unpreserve $attrs ". \"$name\"" val
}

syndicate::spawn actor {
  # This script runs with the syndicate-server connected
  # to its stdio channels. The script is expected to host
  # the initial entity so one is created to receive an
  # assertion of two dataspaces, network and machine.
  set networkEntity [createAssertHandler {value handle} {
    preserves::project $value {^ network-dataspace / } networkDataspace machineDataspace
    if {$networkDataspace == "" || $machineDataspace == ""} {
      puts stderr "unrecognized assertion $value"
      return
    }

    # Accessor for handler scripts.
    proc machineDataspace {} [list return $machineDataspace]

    during {<interface @ifname #? { }>} {
      catch {
        exec ip link set $ifname up
        # Assert information about the interface.
        foreach info [preserves::project [exec ip --json link show $ifname] /] {
          assert "<interface $ifname $info>" [machineDataspace]
        }
      } err
      if {$err != ""} { puts stderr "failed to bring up $ifname: $err" }
      lappend cmdDown exec ip link set $ifname down
      onStop [list catch $cmdDown]
    } $networkDataspace

    during {<address @ifname #? @family #? @attrs #({ })>} {
      # Modify interface addresses.
      projectAttr $attrs local
      projectAttr $attrs prefixlen

      set ifaddr "${local}/$prefixlen"
      lappend cmdAdd exec ip -echo --json address add local $ifaddr dev $ifname

      forattr life_time $attrs {
        lappend cmdAdd valid_lft $life_time preferred_lft $life_time
      }

      # Add address.
      catch {
        # Get information back from the kernel and assert that to the machine dataspace.
        set result [{*}$cmdAdd]
        # Assert the address information reported by the kernel into the machine dataspace.
        foreach info [preserves::project $result /] {
          assert "<address $ifname $family $info>" [machineDataspace]
        }
        # Assert the route information reported by the kernel
        # for this address into the machine dataspace.
        set result [exec ip --json route show $ifaddr dev $ifname]
        foreach info [preserves::project $result /] {
          assert "<route $ifname $family $info>" [machineDataspace]
        }
      } err
      if {$err != ""} { puts stderr "failed to add address $ifaddr to $ifname: $err" }

      # Delete address.
      set cmdDel [lreplace $cmdAdd 5 5 delete]
      onStop [list catch $cmdDel]

    } $networkDataspace

    during {<route @ifname #? @family #? @attrs #({ })>} {
      # Modify routing table.
      lappend cmdAdd exec ip --json route add
      projectAttr $attrs address
      projectAttr $attrs prefixlen

      set dst "$address/$prefixlen"
      # If no address or prefix is present then assume the "default".
      if {$dst eq "/"} { set dst default } else { lappend cmdAdd to }

      forattr type $attrs { lappend cmdAdd $type }
      lappend cmdAdd $dst dev $ifname

      forattr gateway $attrs { lappend cmdAdd via $gateway }

      foreach options [preserves::project $attrs {. options}] {
        foreach key [preserves::project -unpreserve $options {.keys}] {
          preserves::project -unpreserve $options ". $key" val
          lappend cmdAdd $key $val
        }
      }

      # Add route.
      catch {
        {*}$cmdAdd
        # Get route information back from the kernel
        # and assert that to the machine dataspace.
        set cmdShow [lreplace $cmdAdd 4 4 show]
        set result [{*}$cmdShow]
        foreach info [preserves::project $result /] {
          assert "<route $ifname $family $info>" [machineDataspace]
        }
      } err
      if {$err != ""} { puts stderr "failed to add route $dst to $ifname: $err" }

      # Delete route.
      set cmdDel [lreplace $cmdAdd 3 3 delete]
      onStop [list catch $cmdDel]

    } $networkDataspace

  }]

  # The syndicate server is the parent process.
  connectStdio $networkEntity

  # Return from vmwait when the actor dies.
  onStop {set done 1}
}

vwait done
