{ config, pkgs, lib, ... }:
let
  cfg = config.programs.hyprland;
in
{
  options.programs.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hyprland;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."wayland-sessions/hyprland.desktop".source = (pkgs.formats.ini { }).generate "hyprland.desktop" {
      "Desktop Entry" = {
        Name = "Hyprland";
        Comment = "An intelligent dynamic tiling Wayland compositor";
        Exec = "${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}";
        Type = "Application";
        DesktopNames = "Hyprland";
        Keywords = "tiling;wayland;compositor;";
      };
    };
  };
}
