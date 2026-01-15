# provides compatibility options so a finix system can be built with `nixos-rebuild`
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.system.build = {
    nixos-rebuild = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nixos-rebuild-ng;
      internal = true;
    };

    toplevel = lib.mkOption {
      type = lib.types.anything;
      default = config.system.topLevel;
      internal = true;
    };
  };
}
