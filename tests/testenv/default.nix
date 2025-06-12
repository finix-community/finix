{
  pkgs ? import <nixpkgs> {
    overlays = [ (import ../../overlays/default.nix) ];
  }
}:
import ./tcl {
  inherit (pkgs) lib;
  inherit pkgs;
}
