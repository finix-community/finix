{ config, pkgs, lib, ... }:
let
  cfg = config.programs.bash;
in
{
  options.programs.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bashInteractive;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw/bin/bash"
      (lib.getExe cfg.package)
    ];
  };
}
