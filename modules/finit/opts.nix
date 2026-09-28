{ lib, pkgs }:
let
  inherit (lib.types)
    bool
    coercedTo
    either
    enum
    float
    int
    ints
    listOf
    nonEmptyStr
    nullOr
    path
    str
    ;

  format = pkgs.formats.keyValue { };

  pathOrStr = coercedTo path (x: "${x}") str;

  program =
    coercedTo (
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

  strOrNull = value: if value == null then null else toString value;

  # what a finit key may hold: a bare word, a number, a flag, or a list of those
  scalar = lib.types.oneOf [
    str
    int
    bool
    float
  ];

  settingsType = lib.types.attrsOf (
    nullOr (
      lib.types.oneOf [
        scalar
        (listOf scalar)
      ]
    )
  );

  doc = "See [upstream documentation](https://finit-project.github.io/config/service-opts/) for details.";

  settingsOpt = lib.mkOption {
    type = settingsType;
    default = { };
    description = ''
      Freeform `finit` settings for this stanza, added as `key = value` entries to the generated block.
      Escape hatch for keys this module hasn't caught up with yet.

      See [upstream docs](https://finit-project.github.io/config/service-opts/).
    '';
  };

  # key table -> options, and every value folded into `settings`
  mkKeys =
    keys:
    { config, ... }:
    let
      mk = entry: {
        inherit (entry) type;
        default = entry.default or null;
        defaultText =
          entry.defaultText
            or (lib.literalExpression (if entry ? default then toString entry.default else "null"));
        apply = entry.apply or (value: value);
        example = entry.example or null;
        description = entry.desc or doc;
      };
    in
    {
      options = lib.mapAttrs' (name: entry: lib.nameValuePair name (lib.mkOption (mk entry))) keys;

      # an unset key renders as null, false, [] or "", all of which the renderer drops
      config.settings = lib.mapAttrs' (name: _: lib.nameValuePair name config.${name}) keys;
    };

  # keys of a service, task, run or sysv stanza minus runlevel and notify
  svcKeys = {
    description = {
      type = nullOr str;
      desc = "A description of this service, displayed by `initctl`.";
    };

    "if" = {
      type = nullOr nonEmptyStr;
      example = "!int/container";
      desc = ''
        Conditionally load this stanza, evaluated once at the time the `.conf` file is read.
        Either the name of another service, e.g. `"udevd"`, or a condition, e.g. `"!int/container"`

        See [upstream documentation](https://finit-project.github.io/config/services/#conditional-execution) for details.
      '';
    };

    tty = {
      type = nullOr nonEmptyStr;
      example = "/dev/tty1";
      desc = ''
        Give this stanza a controlling terminal on the given device, connecting its `stdin`, `stdout`, and `stderr` to the TTY.
        May be a device node like `/dev/ttyS0` or the special keyword `@console`.

        See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
      '';
    };

    user = {
      type = nullOr str;
      desc = "The user this service is executed as.";
    };
    group = {
      type = nullOr str;
      desc = "The group this service is executed as.";
    };

    "extra-groups" = {
      type = listOf str;
      default = [ ];
      desc = ''
        Explicitly specify supplementary groups, in addition to reading group membership from {file}`/etc/group`.
      '';
    };

    capabilities = {
      type = coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      example = [ "^cap_net_bind_service" ];
      desc = ''
        Allow services to run with minimal required privileges instead of running as `root`.
      '';
    };

    conflicts = {
      type = coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      desc = ''
        If you have conflicting services and want to prevent them from starting.
      '';
    };

    envfile = {
      type = nullOr (either str path);
      apply = strOrNull;
      desc = "either a path or a path prefixed with a '-' to indicate a missing file is fine.";
    };

    manual-start = {
      type = bool;
      default = false;
      desc = ''
        If a service should not be automatically started, it can be configured as manual.
        The service can then be started at any time by running `initctl start <service>`.
      '';
    };

    pidfile = {
      type = nullOr str;
    };
    type = {
      type = nullOr (enum [ "forking" ]);
    };

    respawn = {
      type = bool;
      default = false;
      desc = ''
        Enable endless restarts without counting toward the retry limit.
        When set, the servicewill be restarted indefinitely regardless of the `restart-max` limit.
      '';
    };

    restart-max = {
      type = nullOr (ints.between (-1) 255);
      desc = ''
        The number of times `finit` tries to restart a crashing service.
        When this limit is reached the service is marked crashed and must be restarted manually with `initctl restart NAME`.
        When `null`, finit's built-in of 10 applies.
      '';
    };

    restart-sec = {
      type = nullOr ints.unsigned;
      desc = ''
        The number of seconds before Finit tries to restart a crashing service,
        default: `2` seconds for the first five retries, then back-off to `5` seconds.
        The maximum of this configured value and the above (`2` and `5`) will be used.
      '';
    };

    oncrash = {
      type = nullOr (enum [
        "reboot"
        "script"
      ]);
      desc = ''
        - `reboot` - when all retries have failed, and the service has crashed, if this option is set the system is rebooted.
        - `script` - similarly, but instead of rebooting, call the `exec-stop-post` script if set.
      '';
    };

    stop-timeout = {
      type = nullOr (ints.between 1 300);
      defaultText = "3";
      desc = ''
        The delay in seconds between `finit` sending a `SIGTERM` and a `SIGKILL`.
      '';
    };

    "exec-start-pre" = {
      type = nullOr program;
      default = null;
      desc = "A script which will be called before the service is started.";
    };
    "exec-start-ready" = {
      type = nullOr program;
      default = null;
      desc = "A script which will be called when the service is ready.";
    };
    "exec-stop" = {
      type = nullOr program;
      default = null;
      desc = "Some services may require alternate methods to be stopped.";
    };
    "exec-stop-post" = {
      type = nullOr program;
      default = null;
      desc = "A script which will be called after the service has stopped.";
    };
    "exec-reload" = {
      type = nullOr program;
      default = null;
      example = "kill -HUP $MAINPID";
      desc = ''
        Some services do not support `SIGHUP` but may have other ways to update the
        configuration of a running daemon. When `exec-reload` is defined it is
        preferred over `SIGHUP`. Like `systemd`, `finit` sets `$MAINPID` as a
        convenience to scripts, which in effect also allow setting
        `exec-reload` to `kill -HUP $MAINPID`.
      '';
    };
    "exec-cleanup" = {
      type = nullOr program;
      default = null;
      desc = "A script which will be called when the service is removed.";
    };
  };

  # the initramfs gets a subset: no envfile, no log, no cgroups, no lifecycle scripts
  initrdKeys = {
    inherit (svcKeys)
      description
      "if"
      tty
      respawn
      "restart-max"
      ;
  };

  # readiness, service and sysv stanzas only
  mkServiceOpts =
    {
      readiness,
      notify ? [
        "pid"
        "systemd"
        "s6"
        "none"
      ],
      nohup ? true, # the initramfs has no nohup, its stanzas are not reloaded
    }:
    { config, ... }:
    {
      imports = [
        (mkKeys {
          notify = {
            type = nullOr (enum notify);
            default = readiness;
            defaultText = lib.literalExpression "config.finit.readiness";
          };
        })
      ];

      options = lib.optionalAttrs nohup {
        nohup = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            Set when the service does *not* handle `SIGHUP`. `finit` then stops and
            starts it on reconfiguration instead of reloading it in place.

            See [upstream documentation](https://finit-project.github.io/conditions/) for details.
          '';
        };
      };

      config = lib.optionalAttrs nohup {
        nohup = lib.mkDefault (config.notify == "s6");
      };
    };

  # options of every stanza type: the freeform hatch, the switch to render at all, and the two keys a tty takes as well
  mkBaseOpts = defaultRunlevel: {
    imports = [
      (lib.mkRenamedOptionModule [ "runlevels" ] [ "runlevel" ])
      (mkKeys {
        runlevel = {
          type = str; # TODO: string matching 0-9S
          default = defaultRunlevel;
          desc = "See [upstream documentation](https://finit-project.github.io/runlevels/) for details.";
        };

        conditions = {
          type = coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
          apply = lib.unique;
          default = [ ];
          example = "pid/syslog";
          desc = "See [upstream documentation](https://finit-project.github.io/conditions/) for details.";
        };
      })
    ];

    options = {
      enable = lib.mkOption {
        type = bool;
        default = true;
        description = ''
          Whether to enable this stanza.
        '';
      };

      settings = settingsOpt;
    };
  };

  # name/id/command: what the block is, and where it comes from
  execOptsBase = {
    options = {
      name = lib.mkOption {
        type = str; # TODO: limit name to specific chars: like no : allowed
        readOnly = true;
        description = ''
          The name of this stanza, derived from the attribute name.
        '';
      };

      id = lib.mkOption {
        type = nullOr str;
        readOnly = true;
        description = ''
          The instance identifier, derived from the attribute name if it contains an `@` character.
        '';
      };

      command = lib.mkOption {
        type = program;
        description = ''
          The command to execute.
        '';
      };
    };
  };

  # service, task, run and sysv stanzas of the main system
  mkExecOpts =
    { globalPath }:
    { config, name, ... }:
    {
      imports = [
        (mkKeys svcKeys)
        (lib.mkRenamedOptionModule [ "caps" ] [ "capabilities" ])
        (lib.mkRenamedOptionModule [ "cleanup" ] [ "exec-cleanup" ])
        (lib.mkRenamedOptionModule [ "conflict" ] [ "conflicts" ])
        (lib.mkRenamedOptionModule [ "env" ] [ "envfile" ])
        (lib.mkRenamedOptionModule [ "kill" ] [ "stop-timeout" ])
        (lib.mkRenamedOptionModule [ "manual" ] [ "manual-start" ])
        (lib.mkRenamedOptionModule [ "pid" ] [ "pidfile" ])
        (lib.mkRenamedOptionModule [ "post" ] [ "exec-stop-post" ])
        (lib.mkRenamedOptionModule [ "pre" ] [ "exec-start-pre" ])
        (lib.mkRenamedOptionModule [ "ready" ] [ "exec-start-ready" ])
        (lib.mkRenamedOptionModule [ "reload" ] [ "exec-reload" ])
        (lib.mkRenamedOptionModule [ "restart" ] [ "restart-max" ])
        (lib.mkRenamedOptionModule [ "restart_sec" ] [ "restart-sec" ])
        (lib.mkRenamedOptionModule [ "stop" ] [ "exec-stop" ])
        (lib.mkRenamedOptionModule [ "supplementary_groups" ] [ "extra-groups" ])
      ];

      options = {
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

        path = lib.mkOption {
          type = listOf (either lib.types.package str);
          default = [ ];
          description = ''
            Packages added to the `PATH` environment variable of this service, on top of `finit.path`.
          '';
        };

        log = lib.mkOption {
          type = either bool nonEmptyStr;
          default = false;
          description = ''
            Redirect `stderr` and `stdout` of the application to a file or `syslog` using the native `logit` tool.
            This is useful for programs that do not support `syslog` on their own, which is sometimee the case when running in the foreground.

            See [upstream documentation](https://finit-project.github.io/config/logging/) for additional details.
          '';
        };

        reload-triggers = lib.mkOption {
          type = listOf (either str path);
          default = [ ];
          description = ''
            An arbitrary list of items such as derivations.
            If any item in the list changes between reconfigurations,
            the service will be reloaded or restarted if reloads are not supported.
          '';
        };
      };

      config = {
        # the block title is the identity, `foo@bar` is an instance of `foo`, and a trailing `foo@` makes the stanza a %i template
        name = lib.head (lib.splitString "@" name);
        id =
          if lib.hasSuffix "@" name then
            "%i"
          else if lib.hasInfix "@" name then
            lib.elemAt (lib.splitString "@" name) 1
          else
            null;

        # a stanza with its own `path` extends the global one
        # it does not replace it: `finit.path` is what every other stanza sees
        environment.PATH = lib.mkIf (config.path != [ ]) (lib.makeBinPath (globalPath ++ config.path));

        envfile = lib.mkIf (config.environment != { }) (
          format.generate "${config.name}.env" config.environment
        );
      };
    };

  # the same minus everything the initramfs has no use for
  mkInitrdExecOpts = { name, ... }: {
    imports = [
      (lib.mkRenamedOptionModule [ "restart" ] [ "restart-max" ])
      (mkKeys initrdKeys)
    ];

    config = {
      name = lib.head (lib.splitString "@" name);
      id = if lib.hasInfix "@" name then lib.elemAt (lib.splitString "@" name) 1 else null;
    };
  };

  # tty NAME { device = … } the built-in getty, an external one, or a shell
  ttyOpts =
    { name, config, ... }:
    {
      options = {
        id = lib.mkOption {
          type = nullOr nonEmptyStr;
          default = null;
          description = ''
            Explicit instance ID for the TTY. If not set, finit auto-derives it from the device name
            (e.g., `tty1` becomes `:1`, `ttyS0` becomes `:S0`).
          '';
        };

        device = lib.mkOption {
          type = nullOr nonEmptyStr;
          default = null;
          description = ''
            Embedded systems may want to enable automatic `device` by supplying the special `@console` device.
            This works regardless weather the system uses `ttyS0`, `ttyAMA0`, `ttyMXC0`, or anything else.
            `finit` figures it out by querying sysfs: `/sys/class/tty/console/active`.
          '';
        };

        command = lib.mkOption {
          type = nullOr program;
          default = null;
          description = ''
            Specify an external `getty`, like `agetty` or the BusyBox `getty`.
          '';
        };

        baud = lib.mkOption {
          type = nullOr nonEmptyStr;
          default = null;
          description = ''
            Baud rate for serial TTYs.
          '';
        };

        term = lib.mkOption {
          type = nullOr nonEmptyStr;
          default = null;
          description = ''
            The `TERM` environment variable value for the TTY.
          '';
        };

        noclear = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            Disables clearing the TTY after each session. Clearing the TTY when a user logs out is usually preferable.
          '';
        };

        nowait = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            Disables the press `Enter to activate console` message before actually starting the `getty` program.
          '';
        };

        nologin = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            Disables `getty` and `/bin/login`, and gives the user a `root` (login) shell on the given TTY `device` immediately.
            Needless to say, this is a rather insecure option, but can be very useful for dev builds, during board bringup or similar.
          '';
        };

        rescue = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            Start `sulogin` instead of a regular shell, requiring the root password. Useful for rescue/single-user mode.
          '';
        };

        notty = lib.mkOption {
          type = bool;
          default = false;
          description = ''
            No device node mode. This is insecure and intended only for board bringup or testing scenarios.
          '';
        };
      };

      # a device opens the built-in getty which a rescue/board-bringup shell has no use for
      # finit ignores notty and rescue when a device is set
      config = {
        device = lib.mkIf (config.command == null && !config.notty && !config.rescue) (lib.mkDefault name);
      };
    };

  # `run` [PRIO] ordering only, never a key
  runOpts = {
    options.priority = lib.mkOption {
      type = ints.unsigned;
      default = 1000;
      description = ''
        Order of this `run` command in relation to the others.
        The semantics are the same as with `lib.mkOrder`.
        Smaller values have a greater priority.
      '';
    };
  };

  # task and run stanzas only
  oneshotOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "remain" ] [ "remain-after-exit" ])
      (mkKeys {
        "remain-after-exit" = {
          type = bool;
          default = false;
          desc = ''
            By default, a `run` or `task` will re-run each time its runlevel is entered and its `exec-stop-post` script does not run on completion.

            With `remain-after-exit`, the task runs once and does not re-run on runlevel.
            The `exec-stop-post` script will run if the task is explicitly stopped or when the task leaves its valid runlevels.
          '';
        };
      })
    ];
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

  rlimitOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "rlimits" ] [ "rlimit" ])
    ];

    options.rlimit = lib.mkOption {
      type = rlimitsType;
      default = { };
      description = ''
        An attribute set of resource limits that will be apply by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/runlevels/#resource-limits) for additional details.
      '';
    };
  };

  # the cgroups finit creates on its own, cf. `cgroupOpt` below
  cgroupOpts =
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = str; # TODO: add constraints based on finit
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

  # the per-stanza one which stage1 (the initramfs) has no use for
  cgroupOpt.options.cgroup = {
    name = lib.mkOption {
      type = str;
      default = "system";
      description = ''
        The name of the cgroup to place this process under.
      '';
    };

    delegate = lib.mkOption {
      type = bool;
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
in
{
  inherit
    mkKeys
    mkBaseOpts
    execOptsBase
    mkExecOpts
    mkServiceOpts
    mkInitrdExecOpts
    ttyOpts
    runOpts
    oneshotOpts
    rlimitsType
    rlimitOpts
    cgroupOpts
    cgroupOpt
    ;
}
