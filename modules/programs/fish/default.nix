{ config, pkgs, lib, ... }:
let
  cfg = config.programs.fish;
in
{
  options.programs.fish = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fish;
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      pathsToLink = [ "/share/fish" ];
      systemPackages = [ cfg.package ];
      shells = [
        "/run/current-system/sw/bin/bash"
        (lib.getExe cfg.package)
      ];
    };
  };
}
