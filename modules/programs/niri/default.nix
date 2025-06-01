{ config, pkgs, lib, ... }:
let
  cfg = config.programs.niri;
in
{
  options.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."wayland-sessions/niri.desktop".source = (pkgs.formats.ini { }).generate "niri.desktop" {
      "Desktop Entry" = {
        Name = "Niri";
        Comment = "A scrollable-tiling Wayland compositor";
        Exec = "${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package} --session";
        Type = "Application";
        DesktopNames = "niri";
      };
    };
  };
}
