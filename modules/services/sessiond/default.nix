{
  modules,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sessiond;

  format = pkgs.formats.toml { };
  configFile = format.generate "sessiond.toml" cfg.settings;
in
{
  imports = [ modules.polkit ];

  options.services.sessiond = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sessiond](${pkgs.sessiond.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sessiond;
      defaultText = lib.literalExpression "pkgs.sessiond";
      description = ''
        The package to use for `sessiond`.
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
      type = format.type;
      default = { };
      description = ''
        `sessiond` configuration. See [upstream documentation](https://tangled.org/r0chd.pl/sessiond/blob/master/docs/CONFIGURATION.md)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package ];

    services.polkit.enable = true;

    finit.services.sessiond = {
      description = "daemon for power management";
      conditions = "service/dbus/ready";
      command = "${lib.getExe' cfg.package "sessiond"} --config ${configFile} --log-target syslog";
      notify = "systemd";
      environment =
        if cfg.debug then
          {
            LOG_LEVEL = "debug";
          }
        else
          {
            LOG_LEVEL = lib.mkDefault "info";
          };
    };
  };
}
