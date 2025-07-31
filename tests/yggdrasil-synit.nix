{ testenv ? import ./testenv { } }:

testenv.mkTest {
  name = "yggdrasil-synit";

  nodes.machine = { lib, pkgs, ... }: {
    boot.serviceManager = "synit";

    system.services.yggdrasil = {
      imports = [ pkgs.yggdrasil.passthru.services ];
    };
  };

  tclScript = ''
    machine spawn
    machine expect {synit_pid1: Awaiting signals...}
    machine expect {syndicate_server: inferior server instance}
    machine expect {UNIX admin socket listening on /var/run/yggdrasil/yggdrasil.sock}
    machine expect {Interface IPv6: 2*/7}
    success
  '';
}
