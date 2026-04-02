{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.udisks2;

  format = pkgs.formats.ini { };
in
{
  options.services.udisks2 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [udisks2](${pkgs.udisks2.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.udisks2;
      defaultText = lib.literalExpression "pkgs.udisks2";
      description = ''
        The package to use for `udisks2`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = { };
      description = ''
        `udisks2` configuration. See {manpage}`udisks2.conf(8)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.udisks2.settings = {
      udisks2 = {
        modules = [ "*" ];
        modules_load_preference = "ondemand";
      };
      defaults = {
        encryption = "luks2";
      };
    };

    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.udisks2 = {
      description = "disk manager";
      command = "${cfg.package}/libexec/udisks2/udisksd" + lib.optionalString cfg.debug " --debug";
      conditions = "service/dbus/ready";
      log = true;
    };
  };
}
