{ testenv ? import ./testenv { } }:

testenv.mkTest {
  name = "finit";
  nodes.machine = {
    boot.serviceManager = "finit";
    finit.runlevel = 2;
    services.mdevd.enable = true;
    services.dhcpcd.enable = true;
  };
  tclScript = ''
    set timeout 20

    machine spawn
    machine expect "finix - stage 1"
    machine expect "finix - stage 2"
    machine expect "entering runlevel S"
    machine expect "entering runlevel 2"
    machine expect "getty on /dev/tty1"
    success
  '';
}
