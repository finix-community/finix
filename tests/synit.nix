{ testenv ? import ./testenv { } }:

testenv.mkTest {
  name = "synit";
  nodes.machine = {
    boot.serviceManager = "synit";
    services.dhcpcd.enable = true;
  };
  tclScript = ''
    machine spawn
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    machine expect {<milestone system-machine>*{state: up}}
    machine expect {eth0: carrier acquired}
    machine expect {eth0: adding default route via 10.0.2.2}
    success
  '';
}
