{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.sessiond-power;

  format = pkgs.formats.toml { };
  configFile = format.generate "sessiond-power.toml" cfg.settings;
in
{
  options.services.sessiond-power = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sessiond-power](${pkgs.sessiond-power.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sessiond-power;
      defaultText = lib.literalExpression "pkgs.sessiond-power";
      description = ''
        The package to use for `sessiond-power`.
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
        `sessiond` configuration. See [upstream documentation](https://r0chd.tngl.sh/sessiond/clients/client-power.html)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];

    finit.services.sessiond-power = {
      description = "Power action handler for sessiond";
      conditions = [
        "service/sessiond/ready"
      ];
      command = "${lib.getExe cfg.package} --config ${configFile} --log-target syslog";
      environment = {
        LOG_LEVEL = if cfg.debug then "debug" else lib.mkDefault "info";
      };
    };

    services.sessiond-power.settings = {
      reboot = lib.mkDefault [ "/run/current-system/sw/bin/reboot" ];
      poweroff = lib.mkDefault [ "/run/current-system/sw/bin/poweroff" ];
      suspend = lib.mkDefault [ "/run/current-system/sw/bin/suspend" ];
    };

    services.sessiond.suppressPowerManagementWarning = true;
  };
}
