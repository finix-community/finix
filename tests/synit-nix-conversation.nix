{
  testenv ? import ./testenv { },
}:

testenv.mkTest {
  name = "synit-nix-conversation";

  nodes.machine =
    { ... }:
    {
      boot.serviceManager = "synit";
      services.dhcpcd.enable = true;

      # /nix/store is a read-only mount
      # so run the daemon with a different
      # store location for this test.
      synit.daemons = rec {
        nix-actor = nix-daemon;
        nix-daemon.env = {
          NIX_STORE_DIR = "/nuscht/store";
          NIX_STATE_DIR = "/nuscht/var";
        };
      };

      # Enable the actor for this test.
      # Also enables the nix-daemon.
      services.nix-actor.enable = true;
    };

  tclScript = ''
    package require syndicate

    # Boot the machine.
    #
    machine spawn
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    set timeout 25
    machine expect {syndicate_server::services::tcp_relay_listener: listening}

    # Spawn an actor at the host.
    syndicate::spawn actor {
      # Connect via TCP to the guest.
      connect {<route [<tcp "127.0.0.1" 2424>]>} guest {

        # Assert and observe at the guest by defult.
        setDefaultTarget $guest

        # Fail on any error answer.
        onAssert {@answer #(<a <error>>)} {
          fail $answer
        }

        # Convenience proc to assert <q> and observe <a>.
        proc request {request replyName script} {
          assert "<q $request>"
          onAssert "<a $request <ok @$replyName #?>>" $script
        }

        # Request an evaluation at the guest.
        proc guestNixEval {expr arg replyName script} {
          request "<nix eval-literal #f \"$expr\" $arg>" $replyName $script
        }

        variable testsStarted
        variable testsPassed

        incr testsStarted
        guestNixEval {_: _: builtins.storeDir} 0 storeDir {
          puts stderr "\nbuiltins.storeDir is $storeDir"
          if {$storeDir != {"/nuscht/store"}} {
            fail "Got $storeDir, expected \"/nuscht/store\"."
          }
          testPass
        }

        # TODO: sandbox the evaluator.
        guestNixEval {_: builtins.readFile} {"/proc/cmdline"} content {
          puts stderr "\nreadFile returned $content"
          testPass
        }

        proc testPass {} {
          variable testsPassed
          variable testsStarted
          if {[incr testsPassed] >= $testsStarted} success
        }
      }
    }

    set timeout 20
    machine expect {wait forever}
  '';
}
