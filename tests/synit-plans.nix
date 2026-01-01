{
  testenv ? import ./testenv { },
}:

let
  inherit (testenv) lib pkgs;
  inherit (pkgs.tclPackages) sycl;

  commonModule =
    { lib, ... }:
    {
      boot.serviceManager = "synit";
      services.dhcpcd.enable = true;

      virtualisation.qemu.nics.eth0.args = [
        "hostfwd=tcp:127.0.0.1:2424-:24"
        "dnssearch=home.arpa"
      ];

      synit.plan.config.testListener = [
        ''
          # Add a listener that exposes the synit service dataspace to any
          # IP address present on eth0.
          $machine ? <ip address _ _ { "local": ?addr }> [
            $config += <require-service  <relay-listener <tcp $addr 24> $config>>
          ]
        ''
      ];
    };
in
testenv.mkTest {
  name = "synit-control";

  nodes.alt = {
    imports = [ commonModule ];
    services.seatd.enable = true;
  };

  nodes.machine =
    { nodes, ... }:
    {
      imports = [ commonModule ];

      # Include the closure of the nodes.alt into this machine.
      system.activation.scripts.altClosure.text = "stat ${nodes.alt.config.system.topLevel}/activatePlan";
    };

  runAttrs = {
    # A the syndicate package to the Tcl library path.
    TCLLIBPATH = [ "${sycl}/lib/${sycl.name}" ];
  };

  testScript =
    { nodes }:
    ''
      package require syndicate

      # Boot the machine.
      #
      machine start
      machine expect {synit_pid1: Awaiting signals...}
      machine expect {syndicate_server: inferior server instance}
      set timeout 25
      machine expect {syndicate_server::services::tcp_relay_listener: listening}

      # Call into the machine to control it.
      # 
      puts stderr "\nspawning host-side Syndicate actor"
      syndicate::spawn actor {
        # Connect via TCP to the guest and monitor service-states.
        connect {<route [<tcp "127.0.0.1" 2424>]>} guest {
            setDefaultTarget $guest

            onAssert {<service-state <plan "default" "${nodes.machine.config.synit.plan.file}"> up>} {
              puts stderr "\nDefault plan is up."

              # Transition to the other nodes configuration
              # by running its activatePlan script.
              message {<exec [ "${nodes.alt.config.system.topLevel}/activatePlan" ]>}
            }

            onAssert {<service-state <plan "default" "${nodes.alt.config.synit.plan.file}"> up>} {
              puts stderr "\nNew plan is up."
            }

          }
      }

      # Wait for the new configuration to go into effect.
      #
      set timeout 30
      machine expect {plans <plan "default" "*-alt.plan.pr" * {state: up}}
      success
    '';
}
