{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.gnome-keyring;
in
{
  options.programs.gnome-keyring.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to enable [gnome-keyring](${pkgs.gnome-keyring.meta.homepage}).
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gnome-keyring ];

    services.dbus.packages = [
      pkgs.gnome-keyring
      pkgs.gcr
    ];

    xdg.portal.portals = [
      pkgs.gnome-keyring
    ];

    security.wrappers.gnome-keyring-daemon = {
      owner = "root";
      group = "root";
      capabilities = "cap_ipc_lock=ep";
      source = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon";
    };
  };
}
