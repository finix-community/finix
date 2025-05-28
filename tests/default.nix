let
  overlay = import ../overlays/default.nix;
in
{
  pkgs ? import <nixpkgs> { overlays = [ overlay ]; },
}:

let
  inherit (pkgs) lib;
  driver = import ./drivers/tcl { inherit pkgs lib; };
in
driver.mkTest {
  name = "first-try";
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
