{ testenv ? import ./testenv { } }:

let
  inherit (testenv) lib pkgs;
  sycl = pkgs.tclPackages.sycl;
in
testenv.mkTest {
  name = "synit";

  nodes.machine = { lib, ... }: {
    boot.serviceManager = "synit";
    services.dhcpcd.enable = true;

    virtualisation.qemu.nics.eth0.args = [
      "hostfwd=tcp:127.0.0.1:2424-:24"
    ];

    environment.etc."/syndicate/services/config-tcp-relay.pr".text = ''
      # Add a listener that exposes the synit service dataspace to any
      # IP address present on eth0.
      $machine ? <address eth0 _ { "local": ?addr }> [
        $config += <require-service  <relay-listener <tcp $addr 24> $config>>
      ]
    '';
  };

  runAttrs = {
    # A the syndicate package to the Tcl library path.
    TCLLIBPATH = [ "${sycl}/lib/${sycl.name}" ];
  };

  tclScript = ''
    package require syndicate

    machine spawn
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    set timeout 20
    machine expect {syndicate_server::services::tcp_relay_listener: listening}

    puts stderr "\nspawning host-side Syndicate actor"
    syndicate::spawn actor {
      # Connect via TCP to the guest and monitor service-states.
      connect {<route [<tcp "127.0.0.1" 2424>]>} guest {
          onAssert {<service-state <daemon @daemon #?> up>} {
            puts stderr "daemon is up: $daemon"
          } $guest
          onAssert {<service-state <milestone @milestone #?> up>} {
            puts stderr "milestone is up: $milestone"
          } $guest
          onAssert {<service-state <milestone system-machine> up>} {
            # Test complete.
            success
          } $guest
        }
    }

    set timeout 60
    machine expect {Error}
  '';
}
