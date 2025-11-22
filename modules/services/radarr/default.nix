{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.radarr;

  format = pkgs.formats.ini { };
  toEnvVars =
    settings:
    settings
    |> (lib.mapAttrsRecursive (
      path: value:
      lib.optionalAttrs (value != null) {
        name = lib.toUpper "RADARR__${lib.concatStringsSep "__" path}";
        value = toString (if lib.isBool value then lib.boolToString value else value);
      }
    ))
    |> (lib.collect (x: lib.isString x.name or false && lib.isString x.value or false))
    |> lib.listToAttrs;
in
{
  options.services.radarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [radarr](${pkgs.radarr.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.radarr;
      defaultText = lib.literalExpression "pkgs.radarr";
      description = ''
        The package to use for `radarr`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          update = {
            mechanism = lib.mkOption {
              type =
                with lib.types;
                nullOr (enum [
                  "external"
                  "builtIn"
                  "script"
                ]);
              default = "external";
              description = "Which update mechanism to use.";
            };

            automatically = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically download and install updates.";
            };
          };

          server = {
            port = lib.mkOption {
              type = lib.types.port;
              default = 7878;
              description = "Port number.";
            };
          };

          log = {
            analyticsEnabled = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Send Anonymous Usage Data.";
            };

            level = lib.mkOption {
              type = lib.types.enum [
                "debug"
                "info"
                "trace"
              ];
              default = "info";
              description = "Log level.";
            };
          };
        };
      };
      default = { };
      description = ''
        `radarr` configuration. See [upstream documentation](https://wiki.servarr.com/radarr/environment-variables)
        for additional details.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/radarr";
      description = ''
        The directory used to store all `radarr` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        system activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `radarr` service starts.
        :::
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "radarr";
      description = ''
        User account under which `radarr` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `radarr` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "radarr";
      description = ''
        Group account under which `radarr` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `radarr` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tmpfiles = lib.optionalAttrs (cfg.dataDir == "/var/lib/radarr") {
      radarr.rules = [
        "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group}"
      ];
    };

    finit.services.radarr = {
      inherit (cfg) user group;

      description = "radarr";
      conditions = [
        "service/syslogd/ready"
        "net/lo/up"
      ];
      command = "${lib.getExe cfg.package} -nobrowser -data=${cfg.dataDir}";
      nohup = true;
      log = true;
      environment = toEnvVars cfg.settings;
    };

    users.users = lib.optionalAttrs (cfg.user == "radarr") {
      radarr = {
        group = cfg.group;
        home = cfg.dataDir;
        uid = config.ids.uids.radarr;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "radarr") {
      radarr.gid = config.ids.gids.radarr;
    };
  };
}
