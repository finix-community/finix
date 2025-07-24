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
    machine expect {eth0: soliciting a DHCP lease}
    set timeout 20
    machine expect {*"machine"*+++*route*"10.0.2.0/24"*}
    success
  '';
}
