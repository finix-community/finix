{
  modules,
  config,
  pkgs,
  lib,
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

    suppressPowerManagementWarning = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to suppress the warning that sessiond 0.3.0 and newer no longer
        manage power actions.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `sessiond` configuration. See [upstream documentation](https://r0chd.tngl.sh/sessiond/configuration.html)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings =
      lib.optional
        (!cfg.suppressPowerManagementWarning && lib.versionAtLeast (lib.getVersion cfg.package) "0.3.0")
        ''
          sessiond no longer manages power actions as of version 0.3.0.
          To silence this warning, set services.sessiond.suppressPowerManagementWarning = true or enable sessiond-power
        '';

    environment.systemPackages = [ cfg.package ];

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package ];

    services.polkit.enable = true;

    services.sessiond.settings.power =
      lib.mkIf (lib.versionOlder (lib.getVersion cfg.package) "0.3.0")
        {
          reboot = lib.mkDefault [ "/run/current-system/sw/bin/reboot" ];
          poweroff = lib.mkDefault [ "/run/current-system/sw/bin/poweroff" ];
          suspend = lib.mkDefault [ "/run/current-system/sw/bin/suspend" ];
        };

    finit.services.sessiond = {
      description = "Session management daemon";
      conditions = "service/dbus/ready";
      command = "${lib.getExe' cfg.package "sessiond"} --config ${configFile} --log-target syslog";
      notify = "systemd";
      cgroup.delegate = true;
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
