{ testenv ? import ./testenv { } }:

testenv.mkTest {
  name = "synit";
  nodes.machine = {
    boot.serviceManager = "synit";
  };
  tclScript = ''
    machine spawn
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    machine expect {<milestone system-machine>*{state: up}}
    success
  '';
}
