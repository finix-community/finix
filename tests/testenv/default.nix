let
  sources = import ../../lon.nix;
in
{
  pkgs ? import sources.nixpkgs { },
}:
import ./tcl {
  inherit (pkgs) lib;
  inherit pkgs;
}
