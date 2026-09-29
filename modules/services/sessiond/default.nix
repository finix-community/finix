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
    environment.systemPackages = [ cfg.package ];

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package ];

    services.polkit.enable = true;

    services.sessiond.settings.power = {
      reboot = lib.mkDefault [ "/run/current-system/sw/bin/reboot" ];
      poweroff = lib.mkDefault [ "/run/current-system/sw/bin/poweroff" ];
      suspend = lib.mkDefault [ "/run/current-system/sw/bin/suspend" ];
    };

    finit.services.sessiond = {
      description = "daemon for power management";
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

    # XDG_SESSION_ID is commonly used by polkit agents to retrieve
    # current session id without calling polkit methods and risking
    # getting stuck in the GIO main loop, this is a problem as polkit
    # interacts with sessiond through ConsoleKit interface where
    # sessions are identified by D-Bus object paths, while XDG_SESSION_ID
    # contains only the raw session ID. As a result, polkit agents may end
    # up comparing a ConsoleKit session object path against a raw session
    # ID and fail to match the current session.
    security.pam.environment.XDG_SESSION_ID = lib.mkForce {
      default = null;
      override = null;
    };
  };
}
