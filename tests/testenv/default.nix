{
  pkgs ? import <nixpkgs> {
    overlays = map (_: import _) [
      ../../overlays/default.nix
      ../../overlays/modular-services.nix
    ];
  },
}:
import ./tcl {
  inherit (pkgs) lib;
  inherit pkgs;
}
