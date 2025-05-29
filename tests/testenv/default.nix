{
  pkgs ? import <nixpkgs> {
    overlays = [ (import ../../overlays/default.nix) ];
  }
}:
{
  inherit (import ./tcl {
    inherit (pkgs) lib;
    inherit pkgs;
  }) mkTest;
}
