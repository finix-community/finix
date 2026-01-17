{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.xdg.portal;
in
{
  options.xdg.portal = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable XDG desktop portals.
      '';
    };

    portals = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        List of XDG desktop portal packages to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.dbus.packages = [ pkgs.xdg-desktop-portal ] ++ cfg.portals;
    environment.systemPackages = [ pkgs.xdg-desktop-portal ] ++ cfg.portals;

    environment.pathsToLink = [
      # Portal definitions and upstream desktop environment portal configurations.
      "/share/xdg-desktop-portal"

      # .desktop files to register fallback icon and app name.
      "/share/applications"
    ];

    # TODO: environment.sessionVariables.NIX_XDG_DESKTOP_PORTAL_DIR = "/run/current-system/sw/share/xdg-desktop-portal/portals";
  };
}
