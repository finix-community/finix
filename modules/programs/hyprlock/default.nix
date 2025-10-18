{ config, pkgs, lib, ... }:
let
  cfg = config.programs.hyprlock;
in
{
  options.programs.hyprlock = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [hyprlock](${pkgs.hyprlock.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hyprlock;
      defaultText = lib.literalExpression "pkgs.hyprlock";
      description = ''
        The package to use for `hyprlock`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.pam.services.hyprlock = {
      text = config.security.pam.services.login.text;
    };
  };
}
