{ testenv ? import ./testenv { } }:

testenv.mkTest {
  name = "finit";
  nodes.machine = {
    finit.enable = true;
    finit.runlevel = 2;
  };
  tclScript = ''
    machine spawn
    machine expect "finix - stage 1"
    machine expect "finix - stage 2"
    machine expect "entering runlevel S"
    machine expect "entering runlevel 2"
    machine expect "getty on /dev/tty1"
    success
  '';
}
