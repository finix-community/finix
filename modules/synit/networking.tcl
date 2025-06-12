#!/usr/bin/env -S tclsh

package require syndicate
namespace import preserves::*

# Evaluate a body when a named attribute is present.
proc forattr {name attrs body} {
  preserves::project -unpreserve $attrs ". $name" $name
  if {$name != ""} $body
}

proc projectAttr {attrs name} {
  upvar $name val
  preserves::project -unpreserve $attrs ". $name" val
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
      onStop [list catch exec ip link set $ifname down]
    } $networkDataspace

    during {<address @ifname #? @family #? @attrs #({ })>} {
      # Modify interface addresses.
      projectAttr $attrs address
      projectAttr $attrs prefixLength

      set ifaddr "${address}/$prefixLength"
      lappend cmdAdd exec ip -echo --json address add local $ifaddr dev $ifname

      # Add address.
      catch {
        # Get information back from the kernel and assert that to the machine dataspace.
        set result [{*}$cmdAdd]
        foreach info [preserves::project $result /] {
          assert "<address $ifname $family $info>" [machineDataspace]
        }
      } err
      if {$err != ""} { puts stderr "failed to add address $ifaddr to $ifname: $err" }

      # Delete address.
      set cmdDel [lreplace $cmdAdd 5 5 delete]
      onStop [list catch $cmdDel]

    } $networkDataspace

    during {<route @ifname #? @family #? @attrs #({ })>} {
      # Modify routing table.
      projectAttr $attrs address
      projectAttr $attrs prefixLength

      set prefix "$address/$prefixLength"
      lappend cmdAdd exec ip -echo --json route add to

      forattr type $attrs { lappend cmdAdd $type }
      lappend cmdAdd $prefix dev $ifname

      forattr via $attrs { lappend cmdAdd via $via }

      foreach options [preserves::project $attrs {. options}] {
        foreach key [preserves::project -unpreserve $options {.keys}] {
          preserves::project -unpreserve $options ". $key" val
          lappend cmdAdd $key $val
        }
      }

      # Add route.
      catch {
        # Get information back from the kernel and assert that to the machine dataspace.
        set result [{*}$cmdAdd]
        foreach info [preserves::project $result /] {
          assert "<route $ifname $family $info>" [machineDataspace]
        }
      } err
      if {$err != ""} { puts stderr "failed to add route $prefix to $ifname: $err" }

      # Delete route.
      set cmdDel [lreplace $cmdAdd 5 5 delete]
      onStop [list catch $cmdDel]

    } $networkDataspace

  }]

  # The syndicate server is the parent process.
  connectStdio $networkEntity

  # Return from vmwait when the actor dies.
  onStop {set done 1}
}

vwait done
