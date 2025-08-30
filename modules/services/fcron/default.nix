{ config, pkgs, lib, ... }:
let
  cfg = config.services.fcron;

  format = pkgs.formats.keyValue { };
  systab = pkgs.writeText "systab" (lib.concatStringsSep "\n" cfg.systab);
in
{
  imports = [
    ./providers.scheduler.nix
  ];

  options.services.fcron = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fcron;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    systab = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
      default = [ ];
    };

    allow = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ "all" ];
    };

    deny = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
    };

    # TODO: in serious need of mkField stuff
    settings = {
      fcrontabs = lib.mkOption {
        type = lib.types.path;
        default = "/var/spool/fcron";
      };

      fifofile = lib.mkOption {
        type = lib.types.path;
        default = "/run/fcron.fifo";
      };

      fcronallow = lib.mkOption {
        type = lib.types.path;
        default = "/etc/fcron.allow";
      };

      fcrondeny = lib.mkOption {
        type = lib.types.path;
        default = "/etc/fcron.deny";
      };

      shell = lib.mkOption {
        type = lib.types.path;
        default = "${pkgs.bash}/bin/bash";
      };

      sendmail = lib.mkOption {
        type = lib.types.path;
        default = "${config.security.wrapperDir}/sendmail";
      };
    };

    configFile = lib.mkOption {
      type = lib.types.package;
      default = format.generate "fcron.conf" cfg.settings;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."fcron.conf" = {
      group = "fcron";
      mode = "0644";
      source = cfg.configFile;
    };

    environment.etc."fcron.allow" = {
      group = "fcron";
      mode = "644";
      text = lib.concatStringsSep "\n" cfg.allow;
    };

    environment.etc."fcron.deny" = {
      group = "fcron";
      mode = "644";
      text = lib.concatStringsSep "\n" cfg.deny;
    };

    security.pam.services.fcrontab = {
      text = ''
        #
        # The PAM configuration file for fcron daemon
        #

        account		required	pam_unix.so
        # Warning : fcron has no way to prompt user for a password !
        auth		required	pam_permit.so
        #auth		required	pam_unix.so nullok
        #auth		required	pam_env.so conffile=/etc/security/pam_env.conf
        session		required	pam_permit.so
        #session		required	pam_unix.so
        session         required        pam_loginuid.so
      '';
    };

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.fcron.rules = [
      "d /var/spool/fcron 0770 fcron fcron"
    ];

    security.wrappers = {
      fcrontab = {
        source = "${cfg.package}/bin/fcrontab";
        owner = "fcron";
        group = "fcron";
        setgid = true;
        setuid = true;
      };
      fcrondyn = {
        source = "${cfg.package}/bin/fcrondyn";
        owner = "fcron";
        group = "fcron";
        setgid = true;
        setuid = false;
      };
      fcronsighup = {
        source = "${cfg.package}/bin/fcronsighup";
        owner = "root";
        group = "fcron";
        setuid = true;
      };
    };

    finit.tasks.fcrontab = {
      description = "reload fcrontab";
      conditions = [ "service/syslogd/ready" "task/suid-sgid-wrappers/success" ];

      # https://github.com/NixOS/nixpkgs/issues/25072
      command = "${cfg.package}/bin/fcrontab -u systab - < ${systab}";

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "fcron.env" ''
        PATH="${lib.makeBinPath [ cfg.package ]}:$PATH"
      '';
    };

    finit.services.fcron = {
      description = "fcron daemon";
      conditions = [ "service/syslogd/ready" "task/fcrontab/success" ];
      command = "${cfg.package}/bin/fcron --foreground" + lib.optionalString cfg.debug " --debug";
    };

    users.users = {
      fcron = {
        uid = config.ids.uids.fcron;
        home = "/var/spool/fcron";
        group = "fcron";
      };
    };

    users.groups = {
      fcron.gid = config.ids.gids.fcron;
    };

    # this module supplies an implementation for `providers.scheduler`
    providers.scheduler.backend = "fcron";
  };
}
