#!/usr/bin/env -S tclsh

package require syndicate

set exitCode 0

syndicate::spawn actor {
  onStop {
    global exitCode
    ::exit $exitCode
  }
  proc exit {code} {
    global exitCode
    set exitCode $code
    stopActor
  }

  connect {<route [<unix "/run/synit/system-bus.sock">]>} bus {
    global argc
    global argv

    if {$argv == {-arguments}} {
      onAssert {<service-state @label #?>} {
        puts stdout $label
      } $bus
      onSync stopActor $bus

    } elseif {$argc == 2} {
      lassign $argv service verb
      switch -regexp $verb {
        -status {
          onAssert "@state #(<service-state $service #_>)" {
            puts stderr $state
          } $bus
          onSync stopActor $bus
        }
        -restart {
          message "<restart-service $service>" $bus
          onSync stopActor $bus
        }
        -run {
          assert "<run-service $service>" $bus
        }
        -block {
          assert "<depends-on $service <service-state <dummy [pid]> ready>>" $bus
          message "<restart-service $service>" $bus
        }
        default {
          puts stderr "unhandled verb \"$verb\""
          exit 1
        }
      }

    } else {
      puts stderr "invalid command-line"
      exit 1
    }
  }
}

vwait forever
