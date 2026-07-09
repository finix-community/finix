{
  config,
  pkgs,
  lib,
  ...
}:

let

  cfg = config.services.docker;

  format = pkgs.formats.json { };
  configFile = format.generate "daemon.json" cfg.settings;
in
{
  imports = [ ./test.nix ];

  options.services.docker = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [docker](${pkgs.docker.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.docker;
      defaultText = lib.literalExpression "pkgs.docker";
      description = ''
        The package to use for `docker`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "docker";
      description = ''
        Group to own any `docker` sockets.

        ::: {.note}
        If you want non-`root` users to be able to access the `docker` daemon commands, add
        them to this group.
        :::
      '';
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ criu ]";
      description = ''
        Extra packages to be be made available to the `docker` daemon process.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          hosts = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ "unix:///run/docker.sock" ];
            description = ''
              Specifies where the `docker` daemon listens for client connections.
              :::
            '';
            example = [
              "unix:///run/docker.sock"
              "tcp://0.0.0.0:2375"
            ];
          };

          live-restore = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable live restore of `docker` when containers are still running.
            '';
          };

          log-driver = lib.mkOption {
            type = lib.types.enum [
              "none"
              "json-file"
              "syslog"
              "journald"
              "gelf"
              "fluentd"
              "awslogs"
              "splunk"
              "etwlogs"
              "gcplogs"
              "local"
            ];
            default = "syslog";
            description = ''
              Default driver for container logs.
            '';
          };

          storage-driver = lib.mkOption {
            type =
              with lib.types;
              nullOr (enum [
                "aufs"
                "btrfs"
                "devicemapper"
                "overlay"
                "overlay2"
                "zfs"
              ]);
            default = null;
            description = ''
              Storage driver to use.

              See [upstream documentation](https://docs.docker.com/storage/storagedriver/select-storage-driver)
              for additional details.

              ::: {.warning}
              When you change the storage driver, any existing images and containers become inaccessible. This is
              because their layers can't be used by the new storage driver. If you revert your changes, you can
              access the old images and containers again, but any that you pulled or created using the new driver
              are then inaccessible.
              :::
            '';
          };
        };
      };
      default = { };
      example = {
        ipv6 = true;
        "live-restore" = true;
        "fixed-cidr-v6" = "fd00::/80";
      };
      description = ''
        `docker` configuration. See [upstream documentation](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file)
        for additional details.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `dockerd`. See [upstream documentation](https://docs.docker.com/reference/cli/dockerd)
        for additional details.
      '';
    };

    prune = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to periodically prune `docker` resources.
        '';
      };

      extraArgs = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [
          "--all"
          "--volumes"
        ];
        description = ''
          Additional arguments to pass to {command}`docker system prune`. See [upstream documentation](https://docs.docker.com/reference/cli/docker/system/prune)
          for additional details.
        '';
      };

      # TODO: share this type with options.providers.scheduler.tasks.*.interval
      interval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = ''
          The interval at which this task should run its specified {option}`command`. Accepts either a
          standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

          If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
          to the `scheduler` implementation and execute exactly as specified.

          If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
          underlying `scheduler` implementation will use its features to decide when best to run.
        '';
      };

      # TODO: implement persistent and randomized delays in scheduler provider
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.prune.enable -> config.providers.scheduler.backend != "none";
        message = "services.docker.prune.enable requires a scheduler backend to be enabled in your system configuration.";
      }
    ];

    services.docker.settings = {
      inherit (cfg) group;
    };

    services.docker.extraArgs = [
      "--config-file=/etc/docker/daemon.json"
    ]
    ++ lib.optionals cfg.debug [
      "--debug"
    ];

    services.docker.extraPackages = [
      config.services.nftables.package or pkgs.nftables
    ]
    ++ lib.optionals (cfg.settings.storage-driver == "zfs") [
      config.boot.zfs.package
    ];

    boot.kernelModules = [
      "bridge"
      "veth"
      "br_netfilter"
      "xt_nat"
    ];

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = lib.mkOverride 98 true;
      "net.ipv4.conf.default.forwarding" = lib.mkOverride 98 true;
    };

    environment.etc."docker/daemon.json".source = configFile;
    environment.systemPackages = [
      cfg.package
    ];

    users.groups = lib.optionalAttrs (cfg.group == "docker") {
      docker = { };
    };

    finit.services.docker = {
      description = "docker daemon";
      conditions = [
        "hook/net/up"
        "service/syslogd/ready"
      ];
      command = "${cfg.package}/bin/dockerd " + lib.escapeShellArgs cfg.extraArgs;
      notify = "systemd";
      reload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
      path = [
        pkgs.kmod
      ]
      ++ cfg.extraPackages;
      log = true;
    };

    providers.scheduler.tasks = lib.optionalAttrs cfg.prune.enable {
      docker-prune = {
        inherit (cfg.prune) interval;

        command = "${lib.getExe pkgs.docker} system prune --force ${toString cfg.prune.extraArgs}";
      };

      docker-prune-all-volumes = lib.mkIf cfg.prune.allVolumes.enable {
        inherit (cfg.prune) interval;

        command = "${lib.getExe pkgs.docker} volume prune --force --all ${toString cfg.prune.allVolumes.extraArgs}";
      };
    };
  };
}
