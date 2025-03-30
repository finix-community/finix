{ config, pkgs, lib, ... }:
let
  cfg = config.services.mariadb;

  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
  configFile = format.generate "my.cnf" cfg.settings;

  mysqldOptions = "--user=${cfg.user} --datadir=${cfg.dataDir} --basedir=${cfg.package}";
in
{
  options.services.mariadb = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mariadb";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "mariadb";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/mariadb";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mariadb;
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      description = ''
        MySQL configuration. Refer to
        <https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html>,
        <https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html>,
        and <https://mariadb.com/kb/en/server-system-variables/>
        for details on supported values.

        ::: {.note}
        MySQL configuration options such as `--quick` should be treated as
        boolean options and provided values such as `true`, `false`,
        `1`, or `0`. See the provided example below.
        :::
      '';
      example = lib.literalExpression ''
        {
          mysqld = {
            key_buffer_size = "6G";
            table_cache = 1600;
            log-error = "/var/log/mysql_err.log";
            plugin-load-add = [ "server_audit" "ed25519=auth_ed25519" ];
          };
          mysqldump = {
            quick = true;
            max_allowed_packet = "16M";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.mariadb.settings.mysqld = {
      datadir = cfg.dataDir;
      port = lib.mkDefault 3306;
    };

    users.users = lib.mkIf (cfg.user == "mariadb") {
      mariadb = {
        inherit (cfg) group;

        isSystemUser = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "mariadb") {
      mariadb = { };
    };

    finit.tasks.mariadb-init = {
      inherit (cfg) user group;

      description = "mariadb database init";
      log = true;

      command = pkgs.writeShellApplication {
        name = "mariadb-init.sh";
        runtimeInputs = with pkgs; [
          coreutils
          nettools
          gnused
        ];
        text = ''
          if ! test -e '${cfg.dataDir}/mysql'; then
            ${cfg.package}/bin/mysql_install_db --defaults-file=/etc/my.cnf ${mysqldOptions}
            touch '${cfg.dataDir}/mysql_init'
          fi
        '';
      };
    };

    finit.services.mariadb = {
      inherit (cfg) user group;

      description = "mariadb database service";
      conditions = [ "service/syslogd/ready" "task/mariadb-init/success" ];
      command = "${cfg.package}/bin/mysqld --defaults-file=/etc/my.cnf ${mysqldOptions}";
      # notify = "systemd";
    };

    environment.systemPackages = [
      cfg.package
    ];

    environment.etc."my.cnf".source = configFile;

    # FIXME: finit doesn't implement Z recursively...
    services.tmpfiles.mariadb.rules = [
      "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group}"
      "Z ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group}"
      "d /run/mysqld 0755 ${cfg.user} ${cfg.group}"
      "Z /run/mysqld 0755 ${cfg.user} ${cfg.group}"
    ];
  };
}
