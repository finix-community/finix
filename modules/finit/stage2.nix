{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.finit;
  format = pkgs.formats.keyValue { };
  finitFmt = import ./format.nix { inherit lib pkgs; };
  inherit (finitFmt)
    program
    bfScalar
    mkBlock
    mkTitle
    mkEntries
    execOptsBase
    runOpts
    ttyOpts
    ;
  baseOpts = finitFmt.mkBaseOpts "234";

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

  cgroupOpts =
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str; # TODO: add constraints based on finit
          default = name;
          description = ''
            The name of the cgroup to create.
          '';
        };

        settings = lib.mkOption {
          type = format.type;
          default = { };
          example = {
            "cpu.weight" = 100;
          };
          description = ''
            Settings to apply to this cgroup.

            See [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) for additional details.
          '';
        };
      };
    };

  # oneshotOpts: options specific to oneshot stanzas (task, run) - not services
  oneshotOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "remain" ] [ "remain-after-exit" ])
    ];

    options.remain-after-exit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        By default, a `run` or `task` will re-run each time its runlevel is
        entered, and its `exec-stop-post` script does not run on completion.

        With `remain-after-exit`, the task runs once and does not re-run on runlevel.
        The `exec-stop-post` script will run if the task is explicitly stopped or when
        the task leaves its valid runlevels.
      '';
    };
  };

  # cgroupOpt: the one per-stanza field baseOpts has here but not in the initrd variant (stage1)
  cgroupOpt.options.cgroup = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "system";
      description = ''
        The name of the cgroup to place this process under.
      '';
    };

    delegate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        For services that need to create their own child `cgroups` (container runtimes like `docker`, `podman`, `systemd-nspawn`, `lxc`, etc...).

        See [upstream documentation](https://finit-project.github.io/config/cgroups/#cgroup-delegation) for details.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        The cgroup settings to apply to this process.

        See [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) for additional details.
      '';
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
          type = with lib.types; listOf str;
          default = [ ];
          description = ''
            Explicitly specify supplementary groups, in addition to reading group membership from {file}`/etc/group`.
          '';
        };

        capabilities = lib.mkOption {
          type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
          apply = lib.unique;
          default = [ ];
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
          type = with lib.types; nullOr (either str path);
          default = null;
          description = "either a path or a path prefixed with a '-' to indicate a missing file is fine.";
        };

        environment = lib.mkOption {
          type = format.type;
          default = { };
          example = {
            TZ = "CET";
          };
          description = ''
            Environment variables passed to this service.
          '';
        };

        log = lib.mkOption {
          type = with lib.types; either bool nonEmptyStr;
          default = false;
          description = ''
            Redirect `stderr` and `stdout` of the application to a file or `syslog` using the native `logit`
            tool. This is useful for programs that do not support `syslog` on their own, which is sometimes
            the case when running in the foreground.

            See [upstream documentation](https://finit-project.github.io/config/logging/) for additional details.
          '';
        };

        manual-start = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            If a service should not be automatically started, it can be configured as
            manual. The service can then be started at any time by running `initctl start <service>`.
          '';
        };

        conflicts = lib.mkOption {
          type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
          apply = lib.unique;
          default = [ ];
          description = ''
            If you have conflicting services and want to prevent them from starting.
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
            default of 10 applies.
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
          type = lib.types.bool;
          default = false;
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

          environment.PATH = lib.mkIf (config.path != [ ]) (lib.makeBinPath config.path);
          envfile = lib.mkIf (config.environment != { }) (
            format.generate "${config.name}.env" config.environment
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
        nohup = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Set when the service does *not* handle `SIGHUP`. `finit` then stops and
            starts it on reconfiguration instead of reloading it in place.

            See [upstream documentation](https://finit-project.github.io/conditions/) for details.
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
          default = cfg.readiness;
          defaultText = lib.literalExpression "config.finit.readiness";
          description = ''
            See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
          '';
        };

        exec-reload = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
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

      config = {
        nohup = lib.mkDefault (config.notify == "s6");
      };
    };

  rlimitOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "rlimits" ] [ "rlimit" ])
    ];

    options = {
      rlimit = lib.mkOption {
        type = rlimitsType;
        default = { };
        description = ''
          An attribute set of resource limits that will be apply by `finit`.

          See [upstream documentation](https://finit-project.github.io/config/runlevels/#resource-limits) for additional details.
        '';
      };
    };
  };

  cgroupBlock =
    cg:
    mkBlock "cgroup" cg.name (
      cg.settings // lib.optionalAttrs (cg.delegate or false) { delegate = true; }
    ) [ ];

  logBlock =
    log:
    if log == false then
      null
    else
      mkBlock "log" null (if log == true then { } else { file = log; }) [ ];

  rlimitBlock =
    r:
    if r == { } then
      null
    else
      mkBlock "rlimit" null (lib.concatMapAttrs (
        n: v:
        if lib.isAttrs v then
          lib.optionalAttrs (v.soft != null) { "soft.${n}" = v.soft; }
          // lib.optionalAttrs (v.hard != null) { "hard.${n}" = v.hard; }
        else
          { ${n} = v; }
      ) r) [ ];

  mkServiceLikeBlock =
    svcType: svc:
    let
      log = logBlock svc.log;
    in
    mkBlock svcType (mkTitle svc.name svc.id) (mkEntries svc) (
      [ (cgroupBlock svc.cgroup) ] ++ lib.optional (log != null) log
    );

  # title = the `finit.ttys` attribute name, since `ttyOpts` has no identity of its own.
  mkTtyBlock = name: svc: mkBlock "tty" (mkTitle name svc.id) (mkEntries svc) [ ];

  mkConfigFile =
    svcType: svc:
    let
      rlimit = rlimitBlock svc.rlimit;
    in
    lib.optionalString (rlimit != null) "${rlimit}\n\n"
    + lib.optionalString (
      svc.reload-triggers != [ ]
    ) "# reload-triggers = ${lib.concatStringsSep ", " svc.reload-triggers}\n\n"
    + mkServiceLikeBlock svcType svc;
in
{
  options.finit = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.finit;
      defaultText = lib.literalExpression "pkgs.finit";
      apply =
        package:
        (package.override (
          {
            plymouthSupport = config.programs.plymouth.enable;
            plymouth = config.programs.plymouth.package;
          }
          //
            lib.optionalAttrs (config.services.keventd.enable && package.override.__functionArgs ? udevSupport)
              {
                udevSupport = true;
              }
        )).overrideAttrs
          (o: {
            configureFlags = o.configureFlags ++ [ "--with-plugin-path=${finix-setup}/lib/finit/plugins" ];
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

        A default is provided by this repository, which assigning to this option
        extends. Use `lib.mkForce` to replace it.
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
      type = with lib.types; attrsOf (submodule [ cgroupOpts ]);
      default = { };
      description = ''
        An attribute set of cgroups (v2) that will be created by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/cgroups/) for additional details.
      '';
    };

    rlimits = lib.mkOption {
      type = rlimitsType;
      default = { };
      description = ''
        An attribute set of resource limits that will be apply by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/runlevels/#resource-limits) for additional details.
      '';
    };

    services = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          cgroupOpt
          execOptsBase
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
          cgroupOpt
          execOptsBase
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
          cgroupOpt
          execOptsBase
          execOpts
          oneshotOpts
          rlimitOpts
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
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          ttyOpts
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
          cgroupOpt
          execOptsBase
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

  config = {
    environment.etc =
      let
        # NOTE: entries under /etc/finit.d are marked as direct-symlink to avoid service reloads on every finix activation

        serviceTree = lib.mapAttrs' (name: service: {
          name = if service.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.text = mkConfigFile "service" service;
        }) (lib.filterAttrs (_: service: service.enable) cfg.services);

        taskTree = lib.mapAttrs' (name: task: {
          name = if task.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.text = mkConfigFile "task" task;
        }) (lib.filterAttrs (_: task: task.enable) cfg.tasks);

        sysvTree = lib.mapAttrs' (name: sysv: {
          name = if sysv.id != "%i" then "finit.d/${name}.conf" else "finit.d/available/${name}.conf";

          value.mode = "direct-symlink";
          value.text = mkConfigFile "sysv" sysv;
        }) (lib.filterAttrs (_: sysv: sysv.enable) cfg.sysv);

        # one file each, so a `run` can have a file scoped `rlimit {}`.
        # The index is the ordering: `run` blocks run in read order, and digits sort ahead of the service and task names.
        runTree =
          let
            pad = i: lib.strings.replicate (3 - lib.stringLength i) "0" + i;
            ordered = lib.sortProperties (
              lib.mapAttrsToList (name: run: {
                inherit name;
                value = run;
                inherit (run) priority;
              }) (lib.filterAttrs (_: run: run.enable) cfg.run)
            );
          in
          lib.listToAttrs (
            lib.imap0 (i: entry: {
              name =
                if entry.value.id != "%i" then
                  "finit.d/${pad (toString i)}-run-${entry.name}.conf"
                else
                  "finit.d/available/${pad (toString i)}-run-${entry.name}.conf";

              value.mode = "direct-symlink";
              value.text = mkConfigFile "run" entry.value;
            }) ordered
          );

        cgroup = lib.concatStringsSep "\n\n" (lib.mapAttrsToList (_: cgroupBlock) cfg.cgroups);

        rlimit =
          let
            b = rlimitBlock cfg.rlimits;
          in
          if b == null then "" else b;

        environment =
          if cfg.environment == { } then "" else (mkBlock "environment" null cfg.environment [ ]) + "\n";

        tty = lib.concatStringsSep "\n\n" (
          lib.filter (s: s != "") (
            lib.mapAttrsToList (name: v: if v.enable then mkTtyBlock name v else "") config.finit.ttys
          )
        );

        configFile = {
          "finit.conf".mode = "direct-symlink";
          "finit.conf".text = ''
            ${environment}
            readiness = ${bfScalar cfg.readiness}
            runlevel  = ${toString cfg.runlevel}

            # cgroups
            ${cgroup}

            # rlimits
            ${rlimit}

            # ttys
            ${tty}
          '';
        };
      in
      lib.mkMerge [
        serviceTree
        taskTree
        sysvTree
        runTree
        configFile
      ];
  };
}
