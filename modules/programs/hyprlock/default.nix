{ config, pkgs, lib, ... }:
let
  cfg = config.programs.hyprlock;
in
{
  options.programs.hyprlock = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hyprlock;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.pam.services.hyprlock = {
      text = config.security.pam.services.login.text;
    };
  };
}
