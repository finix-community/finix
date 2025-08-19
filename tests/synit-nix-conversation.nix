{ testenv ? import ./testenv { } }:

let
  inherit (testenv) lib pkgs;
  inherit (pkgs.tclPackages) sycl;
in
testenv.mkTest {
  name = "synit-nix-conversation";

  nodes.machine = { nodes, ... }: {
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

    # Call host-to-guest through this port.
    virtualisation.qemu.nics.eth0.args = [
      "hostfwd=tcp:127.0.0.1:2424-:24"
    ];

    synit.plan.config.testListener = [''
      # Add a listener that exposes the synit service dataspace to any
      # IP address present on eth0.
      $machine ? <ip address _ _ { "local": ?addr }> [
        $config += <require-service  <relay-listener <tcp $addr 24> $config>>
      ]
    ''];
  
  };

  runAttrs = {
    # Make the syndicate package available.
    TCLLIBPATH = [ "${sycl}/lib/${sycl.name}" ];
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

        guestNixEval {_: _: builtins.nixVersion} 0 nixVersion {
          puts stderr "\nbuiltins.nixVersion is $nixVersion"
          if {$nixVersion != {"${pkgs.nix.version}"}} {
            fail "Got $nixVersion, expected \"${pkgs.nix.version}\"."
          }
          testPass
        }

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
          variable n
          if {[incr n] >= 3} success
        }
      }
    }

    set timeout 20
    machine expect {wait forever}
  '';
}
