# Docker service.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.services.docker;
  # TODO advanced proxy setup when?
  # proxy_env = config.networking.proxy.envVars;
  settingsFormat = pkgs.formats.json { };
  daemonSettingsFile = settingsFormat.generate "daemon.json" cfg.daemon.settings;
  validPrefix = s: builtins.isString s && (hasPrefix "unix://" s || hasPrefix "tcp://" s);

in

{
  ###### interface

  options.services.docker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        This option enables (docker)[https://www.docker.com/], a daemon that manages
        linux containers. Users in the "docker" group can interact with
        the daemon (e.g. to start or stop containers) using the
        {command}`docker` command line tool.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "docker";
      description = ''
        Group to own any unix and tcp sockets defined in `services.docker.listenOptions`.

        ::: {.note}
        If you want non-`root` users to be able to access `docker` daemon commands, add
        them to this group.
        :::
      '';
    };

    # TODO add assertion that prevents any listenOptions with `fd://` as a prefix
    listenOptions = mkOption {
      type = types.listOf types.str;
      default = [ "unix:///run/docker.sock" ];
      description = ''
        A list of unix and tcp sockets docker should listen to. 

        ::: {.note}
        The `fd://` listen option is unavailable on `finix`. 
        :::
      '';
      example = [
        "unix:///run/docker.sock"
        "tcp://0.0.0.0:2375"
      ];
    };

    enableOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When enabled, `dockerd` is started on boot. This is required for
        containers which are created with the
        `--restart=always` flag to work. If this option is
        disabled, docker might be started on demand by socket activation.
      '';
    };

    daemon.settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          live-restore = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Allow dockerd to be restarted without affecting running container.
              This option is incompatible with docker swarm.
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
        Configuration for docker daemon. The attributes are serialized to JSON used as daemon.conf.
        See <https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file>
      '';
    };

    storageDriver = mkOption {
      type = types.nullOr (
        types.enum [
          "aufs"
          "btrfs"
          "devicemapper"
          "overlay"
          "overlay2"
          "zfs"
        ]
      );
      default = null;
      description = ''
        This option determines which Docker
        [storage driver](https://docs.docker.com/storage/storagedriver/select-storage-driver/)
        to use.
        By default it lets docker automatically choose the preferred storage
        driver.
        However, it is recommended to specify a storage driver explicitly, as
        docker's default varies over versions.

        ::: {.warning}
        Changing the storage driver will cause any existing containers
        and images to become inaccessible.
        :::
      '';
    };

    logDriver = mkOption {
      type = types.enum [
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
        This option determines which Docker log driver to use.
      '';
    };

    extraOptions = mkOption {
      type = types.separatedString " ";
      default = "";
      description = ''
        The extra command-line options to pass to
        {command}`docker` daemon.
      '';
    };

    # TODO not implemented
    autoPrune = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to periodically prune Docker resources. If enabled, a
          cron job will run `docker system prune -f`
          as specified by the `dates` option.

          Supported cron providers include `cron`, `fcron`, and `anacron`.

          ::{.note}
          By default this does not prune volumes. Anonymous volumes
          can be pruned by passing "--volumes" to [autoPrune.flags](#opt-virtualisation.docker.autoPrune.flags).

          To prune all volumes (not just anonymous ones) [`autoPrune.allVolumes.enable`](#opt-virtualisation.docker.autoPrune.allVolumes.enable)
          must be used.

          See [upstream documentation](https://docs.docker.com/reference/cli/docker/system/prune/#description) for further information.
        '';
      };

      flags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "--filter=label=<label>" ];
        description = ''
          Any additional flags passed to {command}`docker system prune`.
        '';
      };

      interval = mkOption {
        default = "weekly";
        type = types.str;
        description = ''
          The interval at which `docker system prune` should run. Accepts either a
          standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

          If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
          to the `scheduler` implementation and execute exactly as specified.

          If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
          underlying `scheduler` implementation will use its features to decide when best to run.
        '';
      };

      allVolumes = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to periodically prune all Docker volumes when auto pruning other docker resources
            by running {command}`docker volume prune --force --all`

            To prune only anonymous volumes, instead pass `--volumes` to `autoPrune.flags`
          '';
        };

        flags = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "--filter=label=<label>" ];
          description = ''
            Any additional flags passed to {command}`docker volume prune --force --all`.
          '';
        };
      };

      randomizedDelaySec = mkOption {
        default = "0";
        type = types.singleLineStr;
        example = "45min";
        description = ''
          Add a randomized delay before each auto prune.
          The delay will be chosen between zero and this value.
          This value must be a time span in the format specified by
          {manpage}`systemd.time(7)`
        '';
      };

      persistent = mkOption {
        default = true;
        type = types.bool;
        example = false;
        description = ''
          Takes a boolean argument. If true, the time when the service
          unit was last triggered is stored on disk. When the timer is
          activated, the service unit is triggered immediately if it
          would have been triggered at least once during the time when
          the timer was inactive. Such triggering is nonetheless
          subject to the delay imposed by RandomizedDelaySec=. This is
          useful to catch up on missed runs of the service when the
          system was powered down.
        '';
      };

      scheduler = mkOption {
        default = "cron";
        type = types.str;
        example = "anacron";
        description = "Name of the cron provider to use for the autoPrune functionality.";
      };
    };

    package = mkPackageOption pkgs "docker" { };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "with pkgs; [ criu ]";
      description = ''
        Extra packages to add to PATH for the docker daemon process.
      '';
    };
  };

  ###### implementation

  config = mkIf cfg.enable (mkMerge [
    {
      boot.kernelModules = [
        "bridge"
        "veth"
        "br_netfilter"
        "xt_nat"
      ];
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = mkOverride 98 true;
        "net.ipv4.conf.default.forwarding" = mkOverride 98 true;
      };
      environment.systemPackages = [
        cfg.package
      ];

      users.groups = optionalAttrs (cfg.group == "docker") {
        docker = { };
      };

      finit.services.docker = {
        description = "docker containerization service";
        runlevels = "34";
        conditions = [
          "hook/net/up"
          "service/syslogd/ready"
        ];
        command = "${cfg.package}/bin/dockerd --config-file=${daemonSettingsFile} ${cfg.extraOptions}";
        # environment = proxy_env;
        reload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
        manual = !cfg.enableOnBoot;
        path = [
          pkgs.kmod
        ]
        ++ optional (cfg.storageDriver == "zfs") config.boot.zfs.package
        ++ cfg.extraPackages;
      };

      providers.scheduler = mkIf cfg.autoPrune.enable {
        backend = cfg.autoPrune.scheduler;
        tasks.autoPrune = {
          command = concatMapStringsSep (
            [
              "${cfg.package}/bin/docker"
              "system"
              "prune"
              "-f"
            ]
            ++ cfg.autoPrune.flags
            ++ optionals cfg.autoPrune.allVolumes.enable (
              [
                "${cfg.package}/bin/docker"
                "volume"
                "prune"
                "--force"
                "--all"
              ]
              ++ cfg.autoPrune.allVolumes.flags
            )
          );
          interval = cfg.autoPrune.interval;
        };
      };

      services.docker.daemon.settings = {
        group = "${cfg.group}";
        hosts = cfg.listenOptions;
        log-driver = mkDefault cfg.logDriver;
        storage-driver = mkIf (cfg.storageDriver != null) (mkDefault cfg.storageDriver);
      };

      assertions = [
        {
          assertion = cfg.autoPrune.allVolumes.enable -> cfg.autoPrune.enable;
          message = "Option autoPrune.allVolumes.enable requires autoPrune.enable";
        }
        {
          assertion = cfg.autoPrune.enable -> config.services.${cfg.autoPrune.scheduler}.enable;
          message = "Option autoPrune.enable requires a cron scheduler to be enabled in your system configuration.";
        }
        {
          assertion = all validPrefix values;
          message = "Option listenOptions can only include unix:// and tcp:// as socket types.";
        }
      ];
    }
  ]);
}
