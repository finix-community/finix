{
  config,
  pkgs,
  lib,
  ...
}:
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
      description = ''
        Whether to enable [fcron](${pkgs.fcron.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fcron;
      defaultText = lib.literalExpression "pkgs.fcron";
      description = ''
        The package to use for `fcron`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "--maxserial"
        "5"
        "--firstsleep"
        "60"
      ];
      description = ''
        Additional arguments to pass to `fcron`. See {manpage}`fcron(8)`
        for additional details.
      '';
    };

    systab = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
      default = [ ];
      description = ''
        A list of `cron` jobs to be appended to the system-wide {manpage}`fcrontab(5)`.
      '';
    };

    allow = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ "all" ];
      description = ''
        Users allowed to use `fcrontab` and `fcrondyn`.

        ::: {.note}
        A special name `"all"` acts for everyone.
        :::
      '';
    };

    deny = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Users who are not allowed to use `fcrontab` and `fcrondyn`.

        ::: {.note}
        A special name `"all"` acts for everyone.
        :::
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          shell = lib.mkOption {
            type = lib.types.path;
            default = lib.getExe pkgs.bash;
            defaultText = lib.literalExpression "lib.getExe pkgs.bash";
            description = ''
              Location of default shell called by `fcron` when running a job. When `fcron` runs a job, `fcron` uses the
              value of `SHELL` from the `fcrontab` if any, otherwise it uses the value from `fcron.conf` if any, or in
              last resort the value from `/etc/passwd`.
            '';
          };

          sendmail = lib.mkOption {
            type = lib.types.path;
            default = "${config.security.wrapperDir}/sendmail";
            description = ''
              Location of mailer program called by `fcron` to send job output.
            '';
          };
        };
      };
      default = { };
      description = ''
        `fcron` configuration. See {manpage}`fcron.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.fcron.extraArgs = lib.optionals cfg.debug [ "--debug" ];

    services.fcron.settings = {
      fcrontabs = "/var/spool/fcron";
      fifofile = "/run/fcron.fifo";
      fcronallow = "/etc/fcron.allow";
      fcrondeny = "/etc/fcron.deny";
    };

    environment.etc."fcron.conf" = {
      group = "fcron";
      mode = "0644";
      source = format.generate "fcron.conf" cfg.settings;
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

    services.tmpfiles = lib.optionalAttrs (cfg.settings.fcrontabs == "/var/spool/fcron") {
      fcron.rules = [
        "d ${cfg.settings.fcrontabs} 0770 fcron fcron"
      ];
    };

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
      conditions = [
        "service/syslogd/ready"
        "task/suid-sgid-wrappers/success"
      ];

      # https://github.com/NixOS/nixpkgs/issues/25072
      command = "${cfg.package}/bin/fcrontab -u systab - < ${systab}";

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "fcron.env" ''
        PATH="${lib.makeBinPath [ cfg.package ]}:$PATH"
      '';
    };

    finit.services.fcron = {
      description = "fcron daemon";
      command = "${cfg.package}/bin/fcron --foreground " + lib.escapeShellArgs cfg.extraArgs;
      conditions = [
        "service/syslogd/ready"
        "task/fcrontab/success"
      ];
    };

    users.users = {
      fcron = {
        uid = config.ids.uids.fcron;
        home = cfg.settings.fcrontabs;
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
