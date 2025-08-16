{ config, pkgs, lib, ... }:
let
  cfg = config.programs.labwc;
in
{
  options.programs.labwc = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.labwc;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."wayland-sessions/labwc.desktop".source = (pkgs.formats.ini { }).generate "labwc.desktop" {
      "Desktop Entry" = {
        Name = "labwc";
        Comment = "A wayland stacking compositor";
        Exec = "${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}";
        Icon = "labwc";
        Type = "Application";
        DesktopNames = "labwc;wlroots";
      };
    };
  };
}
