{ config, pkgs, lib, ... }:
let
  cfg = config.services.cron;
in
{
  imports = [
    ./providers.scheduler.nix
  ];

  options.services.cron = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [cron](${pkgs.cronie.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cronie;
      defaultText = lib.literalExpression "pkgs.cronie";
      example = lib.literalExpression ''
        pkgs.cron.override {
          sendmailPath = "/run/wrappers/bin/sendmail";
        };
      '';
      description = ''
        The package to use for `cron`.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "-s" ];
      description = ''
        Additional arguments to pass to `cron`. See {manpage}`cron(8)`
        for additional details.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = with lib.types; attrsOf str;
        options = {
          SHELL = lib.mkOption {
            type = lib.types.path;
            default = lib.getExe pkgs.bash;
            defaultText = lib.literalExpression "lib.getExe pkgs.bash";
            description = ''
              The shell used to execute commands.
            '';
          };

          PATH = lib.mkOption {
            type = with lib.types; listOf (either path package);
            apply = lib.makeBinPath;
            defaultText = lib.literalExpression ''
              [
                ${builtins.dirOf config.security.wrapperDir}
                pkgs.coreutils
              ]
            '';
            description = ''
              Packages added to the `cron` PATH environment variable.
            '';
          };

          MAILTO = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              If `MAILTO` is defined (and non-empty), mail is sent to the specified address. If `MAILTO`
              is defined but empty (`MAILTO = "";`), no mail is sent. Otherwise, mail is sent to the owner
              of the crontab.
            '';
          };

          # cronie extensions: https://man.archlinux.org/man/crontab.5.en

          MAILFROM = lib.mkOption {
            type = with lib.types; nullOr nonEmptyStr;
            default = null;
            description = ''
              If `MAILFROM` is defined (and non-empty), it is used as the envelope sender
              address, otherwise, the username of the executing user is used.

              ::: {.note}
              This variable is also inherited from the `cron` process environment.
              :::

              ::: {.note}
              Both `MAILFROM` and `MAILTO` variables are expanded, so setting them as in the following
              example works as expected:

              ```
              MAILFROM=cron-$USER@cron.com
              ```

              `$USER` is replaced by the system user.
              :::
            '';
          };

          CRON_TZ = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            example = lib.literalExpression "config.time.timeZone";
            description = ''
              The time zone specific for the `cron` table. The user should enter a time according to the
              specified time zone into the table. The time used for writing into a log file is taken from
              the local time zone, where the daemon is running.
            '';
          };

          RANDOM_DELAY = lib.mkOption {
            type = with lib.types; nullOr int;
            default = null;
            description = ''
              Allows delaying job startups by random amount of minutes with upper limit specified
              by this value. The random scaling factor is determined during the cron daemon startup
              so it remains constant for the whole run time of the daemon.
            '';
          };

          CONTENT_TYPE = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              The MIME type and character encoding for the output of a cron job when it is sent
              via email. This allows the mail client to properly display the output, especially
              if it contains rich text or is not plain ASCII.
            '';
          };

          CONTENT_TRANSFER_ENCODING = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              The encoding for email notifications. This is useful for properly displaying special
              characters or when sending emails in a format other than plain text.
            '';
          };
        };
      };
      default = { };
      description = ''
        `crontab` configuration. See {manpage}`crontab(5)`
        for additional details.
      '';
    };

    systab = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
      default = [ ];
      example = lib.literalExpression ''
        [ "* * * * *  test   ls -l / > /tmp/cronout 2>&1"
          "* * * * *  eelco  echo Hello World > /home/eelco/cronout"
        ]
      '';
      description = ''
        A list of `cron` jobs to be appended to the system-wide `crontab`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.cron.settings = {
      PATH = [
        (builtins.dirOf config.security.wrapperDir)
        pkgs.coreutils
      ];
    };

    environment.etc.crontab = {
      mode = "0600";
      text = ''
        # generated by nix, do not edit
        ${lib.concatMapAttrsStringSep "\n" (k: v: "${k}=${toString v}") (lib.filterAttrs (_: v: v != null) cfg.settings)}

        ${lib.concatStringsSep "\n" cfg.systab}
      '';
    };

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.cron.rules = [
      "d /var/cron 0710"
      "d /var/spool 0755 - - -"
      "d /var/spool/cron 0755 - - -"

      # ensure this directory exists - cronie complains if it doesn't
      "d /etc/cron.d"
    ];

    security.wrappers.crontab = {
      setuid = true;
      owner = "root";
      group = "root";
      source = "${cfg.package}/bin/crontab";
    };

    finit.services.cron = {
      description = "cron daemon";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} -n " + lib.escapeShellArgs cfg.extraArgs;
      notify = "pid";
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/cron.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc.crontab.source}
    '';

    # this module supplies an implementation for `providers.scheduler`
    providers.scheduler.backend = lib.mkDefault "cron";
  };
}
