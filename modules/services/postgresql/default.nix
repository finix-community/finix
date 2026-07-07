{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.postgresql // {
    user = "postgres";
    group = "postgres";
  };

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString =
        v: if lib.isString v || lib.isPath v then "'${v}'" else lib.generators.mkValueStringDefault { } v;
    } " = ";
  };
in
{
  options.services.postgresql = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [postgresql](${pkgs.postgresql.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        The package to use for `postgresql`.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `postgresql`. See {manpage}`postgres(1)`
        for additional details.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/postgresql/${cfg.package.psqlSchema}";
      defaultText = lib.literalExpression ''"/var/lib/postgresql/''${config.services.postgresql.package.psqlSchema}"'';
      description = ''
        The directory used to store all `postgresql` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        system activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `postgresql` service starts.
        :::
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `postgresql` configuration. See [upstream documentation](https://www.postgresql.org/docs/current/config-setting.html#CONFIG-SETTING-CONFIGURATION-FILE)
        for additional details.
      '';
    };

    authentication = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        `postgresql` client authentication configuration. See [upstream documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
        for additional details.
      '';
    };

    identity = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        `postgresql` user name maps configuration. See [upstream documentation](https://www.postgresql.org/docs/current/auth-username-maps.html)
        for additional details.
      '';
    };

    initdb = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to create a new `postgresql` database cluster.
        '';
      };

      extraArgs = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = ''
          Additional arguments to pass to `initdb`. See {manpage}`initdb(1)`
          for additional details.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql.initdb.extraArgs = [ "--allow-group-access" ];
    services.postgresql.extraArgs = [
      "--config-file=/etc/postgresql/${cfg.package.psqlSchema}/postgresql.conf"
    ];
    services.postgresql.settings = {
      data_directory = lib.mkForce cfg.dataDir;
      hba_file = "/etc/postgresql/${cfg.package.psqlSchema}/pg_hba.conf";
      ident_file = "/etc/postgresql/${cfg.package.psqlSchema}/pg_ident.conf";
      log_destination = "syslog";

      # drop redundant timestamp and pid
      log_line_prefix = lib.mkDefault "";
    };
    services.postgresql.authentication = lib.mkBefore ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             postgres        peer                    map=postgres
    '';
    services.postgresql.identity = lib.mkBefore ''
      # MAPNAME       SYSTEM-USERNAME      DATABASE-USERNAME
      postgres        ${cfg.user}             postgres
    '';

    environment.systemPackages = [ cfg.package ];

    environment.etc."postgresql/${cfg.package.psqlSchema}/pg_ident.conf".text = cfg.identity;
    environment.etc."postgresql/${cfg.package.psqlSchema}/pg_hba.conf".text = cfg.authentication;
    environment.etc."postgresql/${cfg.package.psqlSchema}/postgresql.conf".source =
      format.generate "postgresql.conf" cfg.settings;

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/postgresql.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."postgresql/${cfg.package.psqlSchema}/postgresql.conf".source}
      # ${config.environment.etc."postgresql/${cfg.package.psqlSchema}/pg_hba.conf".source}
      # ${config.environment.etc."postgresql/${cfg.package.psqlSchema}/pg_ident.conf".source}
    '';

    finit.services.postgresql = {
      inherit (cfg) user group;

      command = "${lib.getExe' cfg.package "postgres"} " + lib.escapeShellArgs cfg.extraArgs;
      path = [ cfg.package ];
      conditions = [
        "service/syslogd/ready"
        "net/lo/up"
      ];
      kill = 120;
    }
    // lib.optionalAttrs cfg.initdb.enable {
      pre = pkgs.writeShellScript "pre.sh" ''
        if [ ! -f "${cfg.dataDir}/PG_VERSION" ]; then
          ${lib.getExe' cfg.package "initdb"} ${lib.escapeShellArgs cfg.initdb.extraArgs} ${cfg.dataDir}
        fi
      '';
    };

    finit.tmpfiles.rules = [
      "d /run/postgresql - ${cfg.user} ${cfg.group}"
    ]
    ++ lib.optionals (cfg.dataDir == "/var/lib/postgresql/${cfg.package.psqlSchema}") [
      "d /var/lib/postgresql 0750 ${cfg.user} ${cfg.group}"
      "d /var/lib/postgresql/${cfg.package.psqlSchema} 0750 ${cfg.user} ${cfg.group}"
    ];

    users.users.${cfg.user} = {
      name = cfg.user;
      group = cfg.group;
      home = cfg.dataDir;
      uid = config.ids.uids.postgres;
    };

    users.groups.${cfg.group} = {
      gid = config.ids.gids.postgres;
    };
  };
}
