{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.forgejo-runner;

  format = pkgs.formats.yaml { };
  configFile = format.generate "config.yml" cfg.settings;
in
{
  options.services.forgejo-runner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [forgejo-runner](${pkgs.forgejo-runner.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.forgejo-runner;
      defaultText = lib.literalExpression "pkgs.forgejo-runner";
      description = ''
        The package to use for `forgejo-runner`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/forgejo-runner";
      description = ''
        The directory used to store all `forgejo-runner` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        service activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `forgejo-runner` service starts.
        :::
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "forgejo-runner";
      description = ''
        User account under which `forgejo-runner` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `forgejo-runner` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "forgejo-runner";
      description = ''
        Group account under which `forgejo-runner` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `forgejo-runner` service starts.
        :::
      '';
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ bash coreutils git nodejs ]";
      description = ''
        Extra packages to be be made available to the `forgejo-runner` daemon process.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          runner.capacity = lib.mkOption {
            type = lib.types.ints.positive;
            default = 1;
            description = ''
              Execute how many tasks concurrently at the same time.
            '';
          };

          runner.labels = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            example = [
              "native:host"
              "bookworm:docker://node:22-bookworm"
            ];
            description = ''
              The labels of a runner are used to determine which jobs the runner can run and how to run them.
            '';
          };

          server.connections = lib.mkOption {
            type = with lib.types; attrsOf format.type;
            default = { };
            example = {
              example = {
                url = "https://example.com/";
                uuid = "c9e50be9-a7c3-4aee-ba35-624c4ff8c519";
                token = "6634bb58be0db23cc013a2e72dd1828ae0257cf";
                fetch_interval = "30s";
              };
            };
            description = ''
              A map of connections to one or more Forgejo instances.
            '';
          };
        };
      };
      default = { };
      description = ''
        `forgejo-runner` configuration. See [upstream documentation](https://forgejo.org/docs/latest/admin/actions/runner-installation/#configuration)
        for additional details.
      '';
    };

    docker.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to allow `forgejo-runner` to run jobs on `docker://` labels, using the
        `docker` daemon provided by {option}`services.docker.enable`.

        ::: {.warning}
        This adds `forgejo-runner` to the {option}`services.docker.group` group, which
        is equivalent to giving it `root` access.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.docker.enable -> config.services.docker.enable or false;
        message = "services.forgejo-runner.docker.enable requires services.docker.enable";
      }
    ];

    services.forgejo-runner.settings = lib.optionalAttrs cfg.debug {
      log.level = "debug";
    };

    environment.etc."forgejo-runner/config.yml".source = configFile;

    finit.services.forgejo-runner = {
      inherit (cfg) user group;

      description = "forgejo runner";
      conditions = [
        "service/syslogd/ready"
        "net/route/default"
      ]
      ++ lib.optionals cfg.docker.enable or false [
        "service/docker/ready"
      ];
      command = "${cfg.package}/bin/forgejo-runner daemon --config /etc/forgejo-runner/config.yml";
      reload-signal = "none";
      log = { };

      stop-timeout = 300;
      restart-sec = 10;

      extra-groups = lib.mkIf cfg.docker.enable or false [
        config.services.docker.group
      ];

      path = cfg.extraPackages;
    }
    // lib.optionalAttrs (cfg.dataDir == "/var/lib/forgejo-runner") {
      state-dir = "forgejo-runner";
      state-dir-mode = "0750";
    };

    users.users = lib.mkIf (cfg.user == "forgejo-runner") {
      forgejo-runner = {
        inherit (cfg) group;

        description = "forgejo runner user";
        home = cfg.dataDir;
      };
    };

    users.groups = lib.mkIf (cfg.group == "forgejo-runner") {
      forgejo-runner = { };
    };
  };
}
