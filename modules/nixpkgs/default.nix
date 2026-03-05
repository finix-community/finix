{ config, lib, ... }:
{
  options.nixpkgs = {
    pkgs = lib.mkOption {
      type = lib.types.pkgs // {
        description = "An evaluation of Nixpkgs; the top level attribute set of packages";
      };
      description = ''
        The `nixpkgs` package set to use for this system.
      '';
    };
  };

  config = {
    _module.args = {
      pkgs = config.nixpkgs.pkgs;
    };
  };
}
