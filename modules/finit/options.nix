{
  config,
  pkgs,
  lib,
  ...
}:
let
  format = import ./format.nix { inherit pkgs lib; } {
    sections = [
      "cgroup"
      "run"
      "service"
      "sysv"
      "task"
      "tty"
    ];
  };

  keyValue = pkgs.formats.keyValue { };

  # finix-setup plugin for early boot initialization
  finix-setup = pkgs.callPackage ../../pkgs/finix-setup {
    extraPackages = lib.unique (
      lib.flatten (
        lib.concatMap (v: lib.optional v.enable (v.packages or [ ])) (
          lib.attrValues config.boot.supportedFilesystems
        )
      )
    );
  };

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

  rlimitsType =
    let
      complexType = lib.types.submodule {
        options = {
          soft = lib.mkOption {
            type = lib.types.nullOr (lib.types.either (lib.types.enum [ "unlimited" ]) lib.types.int);
            default = null;
            description = ''
              The value that the kernel enforces for this resource.
            '';
          };

          hard = lib.mkOption {
            type = lib.types.nullOr (lib.types.either (lib.types.enum [ "unlimited" ]) lib.types.int);
            default = null;
            description = ''
              The ceiling for the soft limit.
            '';
          };
        };
      };
    in
    lib.types.attrsOf (
      lib.types.oneOf [
        (lib.types.enum [ "unlimited" ])
        lib.types.int
        complexType
      ]
    );

  rlimitAttrs = lib.concatMapAttrs (
    k: v:
    if lib.isAttrs v then
      lib.optionalAttrs (v.soft != null) { "soft.${k}" = v.soft; }
      // lib.optionalAttrs (v.hard != null) { "hard.${k}" = v.hard; }
    else
      { ${k} = v; }
  );

  # finix extension options for stanzas
  extensions = [
    "enable"
    "script"
    "environment"
    "path"
    "reload-triggers"
    "name"
    "id"
    "priority"

    # compat from custom finix file format prior to finit version 5
    "caps"
    "cleanup"
    "conflict"
    "env"
    "kill"
    "manual"
    "nohup"
    "pid"
    "post"
    "pre"
    "ready"
    "reload"
    "remain"
    "restart"
    "restart_sec"
    "rlimits"
    "runlevels"
    "stop"
    "supplementary_groups"
  ];

  stanzaTitle = name: svc: if svc.id != null && svc.id != "%i" then "${svc.name}:${svc.id}" else name;

  runOpts = {
    options.priority = lib.mkOption {
      type = lib.types.ints.between 0 9999;
      default = 1000;
      description = ''
        Order of this `run` command in relation to the others. The semantics are the same as
        with `lib.mkOrder`. Smaller values have a greater priority.
      '';
    };
  };

  # initrd stanzas default to the bootstrap runlevel S
  initrdDefaults = {
    config.runlevel = lib.mkDefault "S";
  };

  # oneshotOpts: options specific to oneshot stanzas (task, run) - not services
  oneshotOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "remain" ] [ "remain-after-exit" ])
    ];

    options.remain-after-exit = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        By default, a `run` or `task` will re-run each time its runlevel is
        entered, and its `exec-stop-post` script does not run on completion.

        With `remain-after-exit`, the task runs once and does not re-run on runlevel.
        The `exec-stop-post` script will run if the task is explicitly stopped or when
        the task leaves its valid runlevels.
      '';
    };
  };

  # baseOpts: options shared by ALL stanza types (service, task, run, sysv)
  baseOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "runlevels" ] [ "runlevel" ])
    ];

    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable this stanza.
        '';
      };

      "if" = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
        example = "!int/container";
        description = ''
          Only register this stanza when the given condition is asserted, or
          when the named service exists. Prefix with `!` to invert.

          See [upstream documentation](https://finit-project.github.io/config/services/) for details.
        '';
      };

      conditions = lib.mkOption {
        type = with lib.types; nullOr (coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr));
        apply = v: if v == null then null else lib.unique v;
        default = null;
        example = "pid/syslog";
        description = ''
          See [upstream documentation](https://finit-project.github.io/conditions/) for details.
        '';
      };

      description = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          A human-readable description of this service, displayed by `initctl`.
        '';
      };

      runlevel = lib.mkOption {
        type = with lib.types; nullOr (strMatching "!?[0-9Ss]+");
        default = null;
        description = ''
          See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
        '';
      };

      cgroup = lib.mkOption {
        type =
          with lib.types;
          nullOr (
            attrsOf (
              attrsOf (oneOf [
                bool
                int
                str
              ])
            )
          );
        default = null;
        example = {
          system.delegate = true;
        };
        description = ''
          The cgroup to place this process under, keyed by the name of a
          top-level cgroup. `delegate` hands the subtree over to the service
          itself, for container runtimes like `docker`, `podman`,
          `systemd-nspawn` or `lxc`; every other key names a `cgroup` file.

          See [upstream documentation](https://finit-project.github.io/config/cgroups/#cgroup-delegation)
          and [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
          for additional details.
        '';
      };
    };
  };

  # execOpts: options shared by executable stanzas (service, task, run, sysv) but NOT tty
  execOpts =
    { config, name, ... }:
    {
      imports = [
        (lib.mkRenamedOptionModule [ "caps" ] [ "capabilities" ])
        (lib.mkRenamedOptionModule [ "cleanup" ] [ "exec-cleanup" ])
        (lib.mkRenamedOptionModule [ "conflict" ] [ "conflicts" ])
        (lib.mkRenamedOptionModule [ "env" ] [ "envfile" ])
        (lib.mkRenamedOptionModule [ "manual" ] [ "manual-start" ])
        (lib.mkRenamedOptionModule [ "post" ] [ "exec-stop-post" ])
        (lib.mkRenamedOptionModule [ "pre" ] [ "exec-start-pre" ])
        (lib.mkRenamedOptionModule [ "restart" ] [ "restart-max" ])
        (lib.mkRenamedOptionModule [ "restart_sec" ] [ "restart-sec" ])
        (lib.mkRenamedOptionModule [ "supplementary_groups" ] [ "extra-groups" ])
      ];

      options = {
        name = lib.mkOption {
          type = lib.types.str; # TODO: limit name, no : allowed, only valid chars
          readOnly = true;
          description = ''
            The name of this stanza, derived from the attribute name.
          '';
        };

        id = lib.mkOption {
          type = with lib.types; nullOr str;
          readOnly = true;
          description = ''
            The instance identifier, derived from the attribute name if it contains an `@` character.
          '';
        };

        user = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            The user this service should be executed as.
          '';
        };

        group = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            The group this service should be executed as.
          '';
        };

        extra-groups = lib.mkOption {
          type = with lib.types; nullOr (listOf str);
          default = null;
          description = ''
            Explicitly specify supplementary groups, in addition to reading group membership from {file}`/etc/group`.
          '';
        };

        capabilities = lib.mkOption {
          type = with lib.types; nullOr (coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr));
          apply = v: if v == null then null else lib.unique v;
          default = null;
          example = [ "^cap_net_bind_service" ];
          description = ''
            Allow services to run with minimal required privileges instead of running as `root`.
          '';
        };

        path = lib.mkOption {
          type = with lib.types; listOf (either package str);
          default = [ ];
          description = ''
            Packages added to the `PATH` environment variable of this service.
          '';
        };

        envfile = lib.mkOption {
          type = with lib.types; nullOr (coercedTo path toString str);
          default = null;
          description = ''
            Either a path or a path prefixed with a '-' to indicate a missing file is fine.
          '';
        };

        environment = lib.mkOption {
          type = keyValue.type;
          default = { };
          example = {
            TZ = "CET";
          };
          description = ''
            Environment variables passed to this service.
          '';
        };

        log = lib.mkOption {
          type = with lib.types; nullOr (coercedTo bool (_: { }) (attrsOf format.type));
          default = null;
          example = {
            file = "/dev/console";
          };
          description = ''
            Redirect `stderr` and `stdout` of the application to a file or `syslog` using the native `logit`
            tool. This is useful for programs that do not support `syslog` on their own, which is sometimes
            the case when running in the foreground.

            See [upstream documentation](https://finit-project.github.io/config/logging/) for additional details.
          '';
        };

        tty = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/dev/tty1";
          description = ''
            Give this stanza a controlling terminal on the given device, connecting its `stdin`, `stdout`, and
            `stderr` to the TTY. May be a device node like `/dev/ttyS0` or the special keyword `@console`.

            See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
          '';
        };

        manual-start = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          description = ''
            If a service should not be automatically started, it can be configured as
            manual. The service can then be started at any time by running `initctl start <service>`.
          '';
        };

        conflicts = lib.mkOption {
          type = with lib.types; nullOr (coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr));
          apply = v: if v == null then null else lib.unique v;
          default = null;
          description = ''
            If you have conflicting services and want to prevent them from starting.
          '';
        };

        script = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Shell commands executed as the main process.
          '';
        };

        command = lib.mkOption {
          type = program;
          description = ''
            The command to execute.
          '';
        };

        exec-start-pre = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          description = ''
            A script which will be called before the service is started.
          '';
        };

        exec-stop-post = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          description = ''
            A script which will be called after the service has stopped.
          '';
        };

        exec-cleanup = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          description = ''
            A script which will be called when the service is removed.
          '';
        };

        restart-max = lib.mkOption {
          type = with lib.types; nullOr (ints.between (-1) 255);
          default = null;
          description = ''
            The number of times `finit` tries to restart a crashing service. When
            this limit is reached the service is marked crashed and must be restarted
            manually with `initctl restart NAME`. When `null`, finit's built-in
            default applies.
          '';
        };

        restart-sec = lib.mkOption {
          type = with lib.types; nullOr ints.unsigned;
          default = null;
          description = ''
            The number of seconds before Finit tries to restart a crashing service, default: `2`
            seconds for the first five retries, then back-off to `5` seconds. The maximum of this
            configured value and the above (`2` and `5`) will be used.
          '';
        };

        respawn = lib.mkOption {
          type = with lib.types; nullOr bool;
          default = null;
          description = ''
            Enable endless restarts without counting toward the retry limit. When set, the service
            will be restarted indefinitely regardless of the `restart-max` limit.
          '';
        };

        reload-triggers = lib.mkOption {
          type = with lib.types; listOf (either str path);
          default = [ ];
          description = ''
            An arbitrary list of items such as derivations. If any item in the list
            changes between reconfigurations, the service will be reloaded or restarted
            if reloads are not supported.
          '';
        };
      };

      config =
        let
          value = lib.splitString "@" name;
        in
        {
          name = lib.head value;
          id =
            if lib.hasSuffix "@" name then
              "%i"
            else if lib.hasInfix "@" name then
              lib.elemAt value 1
            else
              null;

          command = lib.mkIf (config.script != "") (
            lib.mkForce (
              pkgs.writeScript (lib.replaceStrings [ "@" ] [ "_" ] name) ''
                #!/bin/sh
                set -eu
                ${config.script}
              ''
            )
          );

          environment.PATH = lib.mkIf (config.path != [ ]) (lib.makeBinPath config.path);
          envfile = lib.mkIf (config.environment != { }) (
            keyValue.generate "${config.name}.env" config.environment
          );
        };
    };

  # serviceOpts: options specific to service and sysv stanzas only
  serviceOpts =
    { config, ... }:
    {
      imports = [
        (lib.mkRenamedOptionModule [ "kill" ] [ "stop-timeout" ])
        (lib.mkRenamedOptionModule [ "pid" ] [ "pidfile" ])
        (lib.mkRenamedOptionModule [ "ready" ] [ "exec-start-ready" ])
        (lib.mkRenamedOptionModule [ "reload" ] [ "exec-reload" ])
        (lib.mkRenamedOptionModule [ "stop" ] [ "exec-stop" ])
      ];

      options = {
        reload-signal = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "none";
          description = ''
            Signal `finit` sends to reload the service, or `"none"` when the
            service does not handle `SIGHUP` and must be stopped and started on
            reconfiguration instead.

            See [upstream documentation](https://finit-project.github.io/config/services/) for details.
          '';
        };

        # compat for the pre-v5 spelling
        nohup = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Set when the service does *not* handle `SIGHUP`. Sets
            `reload-signal = "none"`.
          '';
        };

        pidfile = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            See [upstream documentation](https://finit-project.github.io/config/services/) for details.
          '';
        };

        type = lib.mkOption {
          type = with lib.types; nullOr (enum [ "forking" ]);
          default = null;
          description = ''
            Service type. Set to `"forking"` for traditional daemons that fork
            to the background and use PID files for process tracking.
          '';
        };

        notify = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "pid"
              "systemd"
              "s6"
              "none"
            ]);
          default = null;
          description = ''
            When null the stanza inherits `finit.readiness`, cf. `service.c`.

            See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
          '';
        };

        exec-reload = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          apply =
            value:
            if value != null then "'" + (lib.removeSuffix "'" (lib.removePrefix "'" value)) + "'" else null;
          example = "kill -HUP $MAINPID";
          description = ''
            Some services do not support `SIGHUP` but may have other ways to update the configuration of a running daemon. When
            `exec-reload` is defined it is preferred over `SIGHUP`. Like `systemd`, `finit` sets ``$MAINPID` as a convenience to scripts,
            which in effect also allow setting `exec-reload` to `kill -HUP $MAINPID`.

            ::: {.note}
            `exec-reload` is called as PID 1, without any timeout! Meaning, it is up to you to ensure the script is not blocking for
            seconds at a time or never terminates.
            :::
          '';
        };

        exec-stop = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          apply =
            value:
            if value != null then "'" + (lib.removeSuffix "'" (lib.removePrefix "'" value)) + "'" else null;
          description = ''
            Some services may require alternate methods to be stopped. If `exec-stop` is defined it is preferred over `SIGTERM`. Similar
            to `exec-reload`, `finit` sets `$MAINPID`.

            ::: {.note}
            `exec-stop` is called as PID 1, without any timeout! Meaning, it is up to you to ensure the script is not blocking for
            seconds at a time or never terminates.
            :::
          '';
        };

        stop-timeout = lib.mkOption {
          type = with lib.types; nullOr (ints.between 1 300);
          default = null;
          defaultText = "3";
          description = ''
            The delay in seconds between `finit` sending a `SIGTERM` and a `SIGKILL`.
          '';
        };

        exec-start-ready = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          description = ''
            A script which will be called when the service is ready.
          '';
        };

        oncrash = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "reboot"
              "script"
            ]);
          default = null;
          description = ''
            - `reboot` - when all retries have failed, and the service has crashed, if this option is set the system is rebooted.
            - `script` - similarly, but instead of rebooting, call the `exec-stop-post` script if set.
          '';
        };
      };

      config.reload-signal = lib.mkMerge [
        (lib.mkIf config.nohup "none")

        # s6 readiness is not re-asserted on SIGHUP
        (lib.mkIf (config.notify == "s6") (lib.mkDefault "none"))
      ];
    };

  rlimitOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "rlimits" ] [ "rlimit" ])
    ];

    options = {
      rlimit = lib.mkOption {
        type = with lib.types; nullOr rlimitsType;
        apply = v: if v == null then null else rlimitAttrs v;
        default = null;
        description = ''
          An attribute set of resource limits that will be apply by `finit`.

          See [upstream documentation](https://finit-project.github.io/config/runlevels/#resource-limits) for additional details.
        '';
      };
    };
  };

in
{
  options.finit = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.finit;
      defaultText = lib.literalExpression "pkgs.finit";
      apply =
        package:
        let
          args = lib.intersectAttrs (lib.functionArgs package.override) {
            plymouthSupport = config.programs.plymouth.enable;
            plymouth = config.programs.plymouth.package;
            udevSupport = config.services.keventd.enable;
          };
        in
        (package.override args).overrideAttrs (o: {
          configureFlags = o.configureFlags or [ ] ++ [
            "--with-plugin-path=${finix-setup}/lib/finit/plugins"
          ];
        });
      description = ''
        The package to use for `finit`.

        ::: {.note}
        The specified package will have its `configureFlags` appended to with
        a finit plugin path (`--with-plugin-path`) set to the required
        `finix-setup` plugin.
        :::
      '';
    };

    readiness = lib.mkOption {
      type = lib.types.enum [
        "none"
        "pid"
      ];
      default = "none";
      description = ''
        In this mode of operation,
        every service needs to explicitly declare their readiness notification
      '';
    };

    runlevel = lib.mkOption {
      type = lib.types.ints.between 0 9;
      default = 2;
      description = ''
        The runlevel to start after bootstrap, `S`.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf (either path str);
      default = [ ];
      description = ''
        Packages added to the `finit` PATH environment variable.
      '';
    };

    environment = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = ''
        Environment variables passed to *all* `finit` services.
      '';
    };

    cgroups = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          attrsOf (oneOf [
            bool
            int
            str
          ])
        );
      default = { };
      example = {
        system."cpu.weight" = 9800;
      };
      description = ''
        An attribute set of cgroups (v2) that will be created by `finit`, keyed
        by the name of the cgroup. Each key names a `cgroup` file.

        See [upstream documentation](https://finit-project.github.io/config/cgroups/)
        and [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
        for additional details.
      '';
    };

    rlimits = lib.mkOption {
      type = rlimitsType;
      apply = rlimitAttrs;
      default = { };
      description = ''
        An attribute set of resource limits that will be apply by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/runlevels/#resource-limits) for additional details.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        Freeform top-level `finit.conf` settings.
      '';
    };

    services = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          serviceOpts
          rlimitOpts
        ]);
      default = { };
      description = ''
        An attribute set of services, or daemons, to be monitored and automatically
        restarted if they exit prematurely.

        See [upstream documentation](https://finit-project.github.io/config/services/) for additional details.
      '';
    };

    tasks = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          oneshotOpts
          rlimitOpts
        ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to be executed by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    run = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          oneshotOpts
          runOpts
        ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to run in sequence when entering a runlevel. `run` commands
        are guaranteed to be completed before running the next command. Useful when serialization is required.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    ttys = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule [ ./tty.nix ]);
      default = { };
      description = ''
        An attribute set of TTYs that `finit` should manage.

        See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
      '';
    };

    sysv = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          serviceOpts
          rlimitOpts
        ]);
      default = { };
      description = ''
        An attribute set of SysV init scripts to be managed by `finit`. These are
        legacy init scripts that are called with `start`, `stop`, and `restart` arguments.

        See [upstream documentation](https://finit-project.github.io/config/sysv/) for additional details.
      '';
    };
  };

  options.boot.initrd.finit = {
    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        Freeform top-level `finit.conf` settings for the initramfs.
      '';
    };

    services = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          serviceOpts
          rlimitOpts
          initrdDefaults
        ]);
      default = { };
      description = ''
        An attribute set of services, or daemons, to be monitored and automatically
        restarted if they exit prematurely.

        See [upstream documentation](https://finit-project.github.io/config/services/) for additional details.
      '';
    };

    tasks = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          oneshotOpts
          rlimitOpts
          initrdDefaults
        ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to be executed by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    run = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          oneshotOpts
          runOpts
          rlimitOpts
          initrdDefaults
        ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to run in sequence when entering a runlevel. `run` commands
        are guaranteed to be completed before running the next command. Useful when serialization is required.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    ttys = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          ./tty.nix
          initrdDefaults
        ]);
      default = { };
      description = ''
        An attribute set of TTYs that `finit` should manage.

        See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
      '';
    };

    sysv = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          serviceOpts
          rlimitOpts
          initrdDefaults
        ]);
      default = { };
      description = ''
        An attribute set of SysV init scripts to be managed by `finit`. These are
        legacy init scripts that are called with `start`, `stop`, and `restart` arguments.

        See [upstream documentation](https://finit-project.github.io/config/sysv/) for additional details.
      '';
    };
  };

  config = {
    boot.initrd.contents =
      let
        serviceTree = lib.mapAttrsToList (name: svc: {
          target =
            if svc.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = format.generate "${name}.conf" {
            service.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
          };
        }) (lib.filterAttrs (_: svc: svc.enable) config.boot.initrd.finit.services);

        taskTree = lib.mapAttrsToList (name: svc: {
          target =
            if svc.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = format.generate "${name}.conf" {
            task.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
          };
        }) (lib.filterAttrs (_: svc: svc.enable) config.boot.initrd.finit.tasks);

        runTree = lib.mapAttrsToList (name: svc: {
          target =
            if svc.id != "%i" then
              "/etc/finit.d/${lib.fixedWidthNumber 4 svc.priority}-${name}.conf"
            else
              "/etc/finit.d/available/${lib.fixedWidthNumber 4 svc.priority}-${name}.conf";
          source = format.generate "${name}.conf" {
            run.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
          };
        }) (lib.filterAttrs (_: svc: svc.enable) config.boot.initrd.finit.run);

        ttyTree = lib.mapAttrsToList (name: svc: {
          target =
            if svc.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = format.generate "${name}.conf" {
            tty.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
          };
        }) (lib.filterAttrs (_: svc: svc.enable) config.boot.initrd.finit.ttys);

        sysvTree = lib.mapAttrsToList (name: svc: {
          target =
            if svc.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = format.generate "${name}.conf" {
            sysv.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
          };
        }) (lib.filterAttrs (_: svc: svc.enable) config.boot.initrd.finit.sysv);

        # ship generated scripts and envfiles into the initramfs
        scriptFiles =
          lib.concatMap
            (
              svc:
              lib.optional (svc.script or "" != "") { source = svc.command; }
              ++ lib.optional (svc.environment != { }) { source = svc.envfile; }
            )
            (
              lib.filter (svc: svc.enable) (
                lib.attrValues config.boot.initrd.finit.services
                ++ lib.attrValues config.boot.initrd.finit.tasks
                ++ lib.attrValues config.boot.initrd.finit.run
                ++ lib.attrValues config.boot.initrd.finit.sysv
              )
            );
        configFile = lib.singleton {
          target = "/etc/finit.conf";
          source = format.generate "finit.conf" config.boot.initrd.finit.settings;
        };
      in
      lib.mkMerge [
        configFile
        serviceTree
        taskTree
        runTree
        ttyTree
        sysvTree
        scriptFiles
      ];

    environment.etc =
      let
        # NOTE: entries under /etc/finit.d are marked as direct-symlink to avoid service reloads on every finix activation
        configFile = {
          "finit.conf".mode = "direct-symlink";
          "finit.conf".source = format.generate "finit.conf" config.finit.settings;
        };

        serviceTree = lib.mapAttrs' (name: svc: {
          name = if svc.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.source = format.generate "${name}.conf" (
            {
              service.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
            }
            // lib.optionalAttrs (svc.reload-triggers != [ ]) {
              "# reload-triggers" = lib.concatStringsSep ", " svc.reload-triggers;
            }
          );
        }) (lib.filterAttrs (_: svc: svc.enable) config.finit.services);

        taskTree = lib.mapAttrs' (name: svc: {
          name = if svc.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.source = format.generate "${name}.conf" (
            {
              task.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
            }
            // lib.optionalAttrs (svc.reload-triggers != [ ]) {
              "# reload-triggers" = lib.concatStringsSep ", " svc.reload-triggers;
            }
          );
        }) (lib.filterAttrs (_: svc: svc.enable) config.finit.tasks);

        runTree = lib.mapAttrs' (name: svc: {
          name =
            if svc.id != "%i" then
              "finit.d/${lib.fixedWidthNumber 4 svc.priority}-${name}.conf"
            else
              "finit.d/available/${lib.fixedWidthNumber 4 svc.priority}-${name}.conf";

          value.mode = "direct-symlink";
          value.source = format.generate "${name}.conf" (
            {
              run.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
            }
            // lib.optionalAttrs (svc.reload-triggers != [ ]) {
              "# reload-triggers" = lib.concatStringsSep ", " svc.reload-triggers;
            }
          );
        }) (lib.filterAttrs (_: svc: svc.enable) config.finit.run);

        ttyTree = lib.mapAttrs' (name: svc: {
          name = if svc.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.source = format.generate "${name}.conf" (
            {
              tty.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
            }
            // lib.optionalAttrs (svc.reload-triggers != [ ]) {
              "# reload-triggers" = lib.concatStringsSep ", " svc.reload-triggers;
            }
          );
        }) (lib.filterAttrs (_: svc: svc.enable) config.finit.ttys);

        sysvTree = lib.mapAttrs' (name: svc: {
          name = if svc.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.source = format.generate "${name}.conf" (
            {
              sysv.${stanzaTitle name svc} = lib.removeAttrs svc extensions;
            }
            // lib.optionalAttrs (svc.reload-triggers != [ ]) {
              "# reload-triggers" = lib.concatStringsSep ", " svc.reload-triggers;
            }
          );
        }) (lib.filterAttrs (_: svc: svc.enable) config.finit.sysv);
      in
      lib.mkMerge [
        configFile
        serviceTree
        taskTree
        runTree
        ttyTree
        sysvTree
      ];
  };
}
