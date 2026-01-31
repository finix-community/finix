{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.jellyfin;
in
{
  options.services.jellyfin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [jellyfin](${pkgs.jellyfin.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jellyfin;
      defaultText = lib.literalExpression "pkgs.jellyfin";
      description = ''
        The package to use for `jellyfin`.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/jellyfin";
      description = ''
        The directory used to store all `jellyfin` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        system activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `jellyfin` service starts.
        :::
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = ''
        User account under which `jellyfin` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `jellyfin` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = ''
        Group account under which `jellyfin` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `jellyfin` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.jellyfin = {
      inherit (cfg) user group;

      description = "jellyfin media server";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} --datadir ${cfg.dataDir} --configdir ${cfg.dataDir}/config --cachedir /var/cache/jellyfin --logdir /var/log/jellyfin";
      nohup = true;
    };

    finit.tmpfiles.rules = [
      "d /var/cache/jellyfin 0700 ${cfg.user} ${cfg.group}"
      "d /var/log/jellyfin 0750 ${cfg.user} ${cfg.group}"
    ]
    ++ lib.optionals (cfg.dataDir == "/var/lib/jellyfin") [
      "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group}"
      "d ${cfg.dataDir}/config 0700 ${cfg.user} ${cfg.group}"
    ];

    users.users = lib.optionalAttrs (cfg.user == "jellyfin") {
      jellyfin = {
        group = "jellyfin";
        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "jellyfin") {
      jellyfin = { };
    };
  };
}
