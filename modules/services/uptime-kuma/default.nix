{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.uptime-kuma;
  format = pkgs.formats.keyValue { };
in
{
  options.services.uptime-kuma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [uptime-kuma](${pkgs.uptime-kuma.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.uptime-kuma;
      defaultText = lib.literalExpression "pkgs.uptime-kuma";
      description = ''
        The package to use for `uptime-kuma`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          DATA_DIR = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/uptime-kuma";
            description = ''
              Set the directory where the data should be stored.
            '';
          };

          HOST = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = ''
              Host to bind to, could be an ip.
            '';
          };

          PORT = lib.mkOption {
            type = lib.types.port;
            default = 3001;
            description = ''
              Port to listen to.
            '';
          };
        };
      };
      default = { };
      description = ''
        `uptime-kuma` configuration. See [upstream documentation](https://github.com/louislam/uptime-kuma/wiki/Environment-Variables#server-environment-variables)
        for additional details.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
      description = ''
        User account under which `uptime-kuma` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `uptime-kuma` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
      description = ''
        Group account under which `uptime-kuma` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `uptime-kuma` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma.settings = {
      NODE_ENV = "production";
    };

    finit.services.uptime-kuma = {
      inherit (cfg) user group;

      description = "uptime kuma";
      conditions = [
        "service/syslogd/ready"
        "net/route/default"
      ];
      command = lib.getExe cfg.package;
      kill = lib.mkDefault 10;
      nohup = true;
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = cfg.settings;
      path = [ pkgs.unixtools.ping ];
    };

    services.tmpfiles.uptime-kuma = lib.mkIf (cfg.settings.DATA_DIR == "/var/lib/uptime-kuma") {
      rules = [
        "d ${cfg.settings.DATA_DIR} 0750 ${cfg.user} ${cfg.group}"
      ];
    };

    users.users = lib.mkIf (cfg.user == "uptime-kuma") {
      uptime-kuma = {
        group = cfg.group;
      };
    };

    users.groups = lib.mkIf (cfg.group == "uptime-kuma") {
      uptime-kuma = { };
    };
  };
}
