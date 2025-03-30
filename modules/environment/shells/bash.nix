{ pkgs, lib, ... }:
{
  options.environment.shells.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bashInteractive;
    };
  };
}
