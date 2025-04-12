{ config, pkgs, lib, ... }:
let
  cfg = config.services.fcron;

  format = pkgs.formats.keyValue { };

  systab = lib.concatStringsSep "\n" cfg.systab;
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

    systab = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
      default = [ ];
    };

    # TODO: in serious need of mkField stuff
    settings = {
      fcrontabs = lib.mkOption {
        type = lib.types.path;
        default = "/var/spool/fcron";
      };

      # pidfile=file-path (/usr/local/var/run/fcron.pid)

      suspendfile = lib.mkOption {
        type = lib.types.path;
        default = "/var/run/fcron.suspend";
      };

      fifofile = lib.mkOption {
        type = lib.types.path;
        default = "/var/run/fcron.fifo";
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

      # editor=file-path (/usr/bin/vi)
      # maildisplayname=string ()
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
      text = "all";
    };

    environment.etc."fcron.deny" = {
      group = "fcron";
      mode = "644";
      text = "";
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
        #auth		required	pam_env.so
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

    finit.services.fcron = {
      description = "fcron daemon";
      conditions = [ "service/syslogd/ready" "task/suid-sgid-wrappers/success" ];
      command = "${cfg.package}/bin/fcron --foreground --configfile /etc/fcron.conf";

      pre = pkgs.writeShellScript "foo-pre.sh" ''
        ${config.security.wrapperDir}/fcrontab -u systab -r
        ${config.security.wrapperDir}/fcrontab -u systab - < ${pkgs.writeText "systab" systab}
      '';
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
    providers.scheduler.backend = lib.mkDefault "fcron";
  };
}
