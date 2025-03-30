{ config, pkgs, lib, ... }:
let
  cfg = config.services.fcron;

  format = pkgs.formats.keyValue { };

  timers = lib.filterAttrs (_: v: v.enable) config.services.fcron.timers;
  val = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
    let
      # cronExpr = {
      #   "@daily" = "@1d";
      #   "@hourly" = "@1h";
      # }.${v.startAt} or v.startAt;
    in
      # "%runas(${if v.user != null then v.user else "root"}) ${cronExpr} ${v.command}"
      "${v.startAt} ${if v.user != null then v.user else "root"} ${v.command}"
  ) timers);

  pathOrStr = with lib.types; coercedTo path (x: "${x}") str;
  program =
    lib.types.coercedTo (
      lib.types.package
      // {
        # require mainProgram for this conversion
        check = v: v.type or null == "derivation" && v ? meta.mainProgram;
      }
    ) lib.getExe pathOrStr
    // {
      description = "main program, path or command";
      descriptionClass = "conjunction";
    };

  timerOpts = {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      description = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "";
      };

      command = lib.mkOption {
        type = program;
      };

      user = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };

      # TODO:
      # environment = lib.mkOption {
      #   type = lib.type.attrsOf lib.types.str;
      #   default = { };
      # };
      #
      # randomizedDelaySec = lib.mkOption {
      #   type = lib.types.ints.unsigned;
      #   default = 0;
      # };
      #
      # persistent = lib.mkOption {
      #   type = lib.types.bool;
      #   default = false;
      # }

      startAt = lib.mkOption {
        type = lib.types.str;
      };
    };
  };
in
{
  options.services.fcron = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fcron;
    };

    timers = lib.mkOption {
      type = with lib.types; attrsOf (submodule timerOpts);
      default = { };
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
        ${config.security.wrapperDir}/fcrontab -u systab - < ${pkgs.writeText "systab" val}
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
  };
}
