{ config, pkgs, lib, ... }:
let
  cfg = config.services.sonarr;
in
{
  options.services.sonarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sonarr](${pkgs.sonarr.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sonarr;
      defaultText = lib.literalExpression "pkgs.sonarr";
      description = ''
        The package to use for `sonarr`.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sonarr";
      description = ''
        The directory used to store all `sonarr` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        system activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `sonarr` service starts.
        :::
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
      description = ''
        User account under which `sonarr` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `sonarr` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
      description = ''
        Group account under which `sonarr` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `sonarr` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tmpfiles = lib.optionalAttrs (cfg.dataDir == "/var/lib/sonarr") {
      sonarr.rules = [
        "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group}"
      ];
    };

    finit.services.sonarr = {
      inherit (cfg) user group;

      description = "sonarr";
      conditions = [ "service/syslogd/ready" "net/lo/up" ];
      command = "${lib.getExe cfg.package} -nobrowser -data=${cfg.dataDir}";
      nohup = true;
      log = true;
    };

    users.users = lib.optionalAttrs (cfg.user == "sonarr") {
      sonarr = {
        group = cfg.group;
        home = cfg.dataDir;
        uid = config.ids.uids.sonarr;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "sonarr") {
      sonarr.gid = config.ids.gids.sonarr;
    };
  };
}
