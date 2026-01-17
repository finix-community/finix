{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.ytdl-sub;

  format = pkgs.formats.yaml { };
  configFile = format.generate "config.yaml" cfg.settings;
in
{
  options.services.ytdl-sub = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ytdl-sub](${pkgs.ytdl-sub.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ytdl-sub;
      defaultText = lib.literalExpression "pkgs.ytdl-sub";
      description = ''
        The package to use for `ytdl-sub`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ytdl-sub";
      description = ''
        User account under which `ytdl-sub` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `ytdl-sub` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ytdl-sub";
      description = ''
        Group account under which `ytdl-sub` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `ytdl-sub` service starts.
        :::
      '';
    };

    # TODO: share this type with options.providers.scheduler.tasks.*.interval
    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = ''
        The interval at which this task should run its specified {option}`command`. Accepts either a
        standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

        If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
        to the `scheduler` implementation and execute exactly as specified.

        If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
        underlying `scheduler` implementation will use its features to decide when best to run.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `ytdl-sub`. See [upstream documentation](https://ytdl-sub.readthedocs.io/en/latest/usage.html)
        for additional details.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options.configuration = {
          working_directory = lib.mkOption {
            type = lib.types.str;
            default = "/run/ytdl-sub";
            description = ''
              The directory to temporarily store downloaded files before moving them into their final directory.
            '';
          };

          lock_directory = lib.mkOption {
            type = lib.types.str;
            default = "/run/lock/ytdl-sub";
            description = ''
              The directory to temporarily store file locks, which prevents multiple instances of `ytdl-sub` from
              running. Note that file locks do not work on network-mounted directories. Ensure that this directory
              resides on the host machine.
            '';
          };

          persist_logs.logs_directory = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/ytdl-sub";
            description = ''
              Write log files to this directory with names like `YYYY-mm-dd-HHMMSS.subscription_name.(success|error).log`.
            '';
          };

          persist_logs.keep_successful_logs = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              When `true` always writes log files for the subscription both for successful downloads and when it encounters
              an error while downloading. When this key is `false`, only write log files for errors.
            '';
          };
        };
      };
      default = { };
      description = ''
        `ytdl-sub` configuration. See [upstream documentation](https://ytdl-sub.readthedocs.io/en/latest/config_reference/config_yaml.html)
        for additional details.
      '';
    };

    subscriptions = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        "YouTube Playlist" = {
          "Some Playlist" = "https://www.youtube.com/playlist?list=...";
        };
      };
      description = ''
        `ytdl-sub` subscriptions. See [upstream documentation](https://ytdl-sub.readthedocs.io/en/latest/config_reference/subscription_yaml.html)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ytdl-sub.extraArgs = [
      "--config=${configFile}"
    ]
    ++ lib.optionals cfg.debug [ "--log-level=debug" ];

    finit.tmpfiles.rules =
      lib.optionals (cfg.settings.configuration.persist_logs.logs_directory == "/var/log/ytdl-sub") [
        "d /var/log/ytdl-sub 0750 ${cfg.user} ${cfg.group}"
      ]
      ++ lib.optionals (cfg.settings.configuration.working_directory == "/run/ytdl-sub") [
        "d /run/ytdl-sub 0750 ${cfg.user} ${cfg.group}"
      ]
      ++ lib.optionals (cfg.settings.configuration.lock_directory == "/run/lock/ytdl-sub") [
        "d /run/lock/ytdl-sub 0750 ${cfg.user} ${cfg.group}"
      ];

    providers.scheduler.tasks = {
      ytdl-sub = {
        inherit (cfg) interval user;
        command = "${lib.getExe cfg.package} ${lib.escapeShellArgs cfg.extraArgs} sub ${format.generate "subscriptions.yaml" cfg.subscriptions}";
      };
    };

    users.users = lib.optionalAttrs (cfg.user == "ytdl-sub") {
      ytdl-sub = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "ytdl-sub") {
      ytdl-sub = { };
    };
  };
}
