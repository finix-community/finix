{ lib }:
{
  options = import ../../lib/options/base.nix { inherit lib; } // {
    runlevels = lib.mkOption {
      type = lib.types.str; # TODO: string  matching 0-9S
      default = "S";
      description = ''
        See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
      '';
    };
  };
}
