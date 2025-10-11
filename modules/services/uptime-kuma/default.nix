{ config, pkgs, lib, ... }:
let
  cfg = config.services.uptime-kuma;
  format = pkgs.formats.keyValue { };
in
{
  options.services.uptime-kuma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.uptime-kuma;
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          DATA_DIR = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/uptime-kuma";
          };

          HOST = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
          };

          PORT = lib.mkOption {
            type = lib.types.port;
            default = 3001;
          };
        };
      };
      default = { };
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma.settings = {
      NODE_ENV = "production";

      PATH = "${lib.makeBinPath [ pkgs.unixtools.ping ]}:$PATH";
    };

    finit.services.uptime-kuma = {
      inherit (cfg) user group;

      description = "uptime kuma";
      conditions = [ "service/syslogd/ready" "net/route/default" ];
      command = lib.getExe cfg.package;
      kill = lib.mkDefault 10;
      nohup = true;
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = format.generate "uptime-kuma.env" cfg.settings;
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
