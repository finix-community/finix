{ lib, pkgs }@args:

pkgs.formats
// {
  preserves = import ./preserves.nix args;
}
