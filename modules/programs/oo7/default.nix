{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.oo7;
in
{
  options.programs.oo7.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to enable [oo7](${pkgs.oo7.meta.homepage}).
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.oo7 ];

    services.dbus.packages = [ pkgs.oo7-server ];

    xdg.portal.portals = [ pkgs.oo7-portal ];

    security.wrappers.oo7-daemon = {
      owner = "root";
      group = "root";
      capabilities = "cap_ipc_lock=ep";
      source = "${pkgs.oo7-server}/libexec/oo7-daemon";
    };
  };
}
