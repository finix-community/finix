let
  sources = import ../../lon.nix;
in
{
  pkgs ? import sources.nixpkgs {
    overlays = [
      (import ../../overlays/default.nix)
      (import "${sources.sampkgs}/overlay.nix")
    ];
  },
}:
import ./tcl {
  inherit (pkgs) lib;
  inherit pkgs;
}
