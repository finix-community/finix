{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.gvfs;
in
{
  options.services.gvfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [gvfs](${pkgs.gvfs.meta.homepage}) as a `dbus` service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gvfs;
      defaultText = lib.literalExpression "pkgs.gvfs";
      description = ''
        The package to use for `gvfs`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ pkgs.libmtp.out ];
    services.udisks2.enable = true;

    # needed for unwrapped applications
    security.pam.environment = {
      GIO_EXTRA_MODULES.default = "${cfg.package}/lib/gio/modules";
    };
  };
}
