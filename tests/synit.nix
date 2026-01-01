{
  testenv ? import ./testenv { },
}:

testenv.mkTest {
  name = "synit";
  nodes.machine = {
    boot.serviceManager = "synit";
    # TODO(emery): Enable dhcpcd by default in tests.
    services.dhcpcd.enable = true;
  };
  testScript = ''
    package require syndicate
    set timeout 20

    machine start
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    machine expect {eth0: soliciting a DHCP lease}
    machine expect {syndicate_server::services::tcp_relay_listener: listening}

    syndicate::spawn actor {
      connect {<route [<tcp "127.0.0.1" 2424>]>} guest {
        # TODO(emery): Shutdown at the system-bus.
        onAssert {<init @init #?>} {
          puts stderr {Found the init capability.}
          message poweroff $init
        } $guest
      }
    }

    machine expect {synit_pid1: / mounted readonly}
    machine expect {Power down}
    success
  '';
}
