{ config, pkgs, lib, ... }:
let
  cfg = config.finit;

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

  runOpts = {
    options.priority = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        Order of this `run` command in relation to the others. The semantics are the same as
        with `lib.mkOrder`. Smaller values have a greater priority.
      '';
    };
  };

  commonOpts = { config, name, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      extraConfig = lib.mkOption {
        type = lib.types.separatedString " ";
        default = "";
        example = "";
        description = ''
          A place for `finit` configuration options which have not been added to the `nix` module yet.
        '';
      };

      conditions = lib.mkOption {
        type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
        apply = lib.unique;
        default = [ ];
        example = "pid/syslog";
        description = ''
          See [upstream documentation](https://github.com/troglobit/finit/blob/master/doc/conditions.md) for details.
        '';
      };

      description = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };

      runlevels = lib.mkOption {
        type = lib.types.str; # TODO: string  matching 0-9S
        default = "234";
        description = ''
          See [upstream documentation](https://github.com/troglobit/finit?tab=readme-ov-file#runlevels) for details.
        '';
      };
    };
  };

  # TODO: move options common to finit.{run, tasks, ttys, services} from here into commonOpts
  serviceOpts = { config, name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str; # TODO: limit name, no : allowed, only valid chars
      };

      id = lib.mkOption { # TODO: figure out how :%i etc... works
        type = with lib.types; nullOr str; # TODO: limit id, only valid chars
        default = null;
      };

      nohup = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether this service supports reload on SIGHUP.
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

      restart = lib.mkOption {
        type = lib.types.ints.between (-1) 255;
        default = 10;
        description = ''
          The number of times `finit` tries to restart a crashing service. When
          this limit is reached the service is marked crashed and must be restarted
          manually with `initctl restart NAME`.
        '';
      };

      restart_sec = lib.mkOption {
        type = with lib.types; nullOr ints.unsigned;
        default = null;
        description = ''
          The number of seconds before Finit tries to restart a crashing service, default: `2`
          seconds for the first five retries, then back-off to `5` seconds. The maximum of this
          configured value and the above (`2` and `5`) will be used.
        '';
      };

      pid = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          See [upstream documentation](https://github.com/troglobit/finit/blob/master/doc/service.md) for details.
        '';
      };

      type = lib.mkOption {
        type = with lib.types; nullOr (enum [ "forking" ]);
        default = null;
      };

      env = lib.mkOption {
        type = with lib.types; nullOr (either str path);
        default = null;
        description = "either a path or a path prefixed with a '-' to indicate a missing file is fine.";
      };

      log = lib.mkOption {
        type = with lib.types; either bool nonEmptyStr;
        default = false;
        description = ''
          Redirect `stderr` and `stdout` of the application to a file or `syslog` using the native `logit`
          tool. This is useful for programs that do not support `syslog` on their own, which is sometimes
          the case when running in the foreground.

          See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#redirecting-output) for additional details.
        '';
      };

      manual = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If a service should not be automatically started, it can be configured as
          manual. The service can then be started at any time by running `initctl start <service>`.
        '';
      };

      conflict = lib.mkOption {
        type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
        apply = lib.unique;
        default = [ ];
        description = ''
          If you have conflicting services and want to prevent them from starting.
        '';
      };

      notify = lib.mkOption {
        type = with lib.types; nullOr (enum [ "pid" "systemd" "s6" "none" ]);
        default = cfg.readiness;
        defaultText = lib.literalExpression "config.finit.readiness";
        description = ''
          See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#service-synchronization) for details.
        '';
      };

      command = lib.mkOption {
        type = program;
      };

      pre = lib.mkOption {
        type = lib.types.nullOr program;
        default = null;
        description = ''
          A script which will be called before the service is started.
        '';
      };

      post = lib.mkOption {
        type = lib.types.nullOr program;
        default = null;
        description = ''
          A script which will be called after the service has stopped.
        '';
      };

      ready = lib.mkOption {
        type = lib.types.nullOr program;
        default = null;
        description = ''
          A script which will be called when the service is ready.
        '';
      };

      cleanup = lib.mkOption {
        type = lib.types.nullOr program;
        default = null;
        description = ''
          A script which will be called when the service is removed.
        '';
      };

      oncrash = lib.mkOption {
        type = with lib.types; nullOr (enum [ "reboot" "script" ]);
        default = null;
        description = ''
          - `reboot` - when all retries have failed, and the service has crashed, if this option is set the system is rebooted.
          - `script` - similarly, but instead of rebooting, call the `post:script` action if set.
        '';
      };
    };

    config =
      let
        value = lib.splitString "%" name;
      in
        {
          name = lib.head value;
          id = lib.mkIf (builtins.length value == 2) ("%" + lib.elemAt value 1);

          nohup = lib.mkDefault (config.notify == "s6");
        };
  };

  # tty [LVLS] <COND> DEV [BAUD] [noclear] [nowait] [nologin] [TERM]
  # tty [LVLS] <COND> CMD <ARGS> [noclear] [nowait]
  # TODO: assertions that make sure options make sense together
  # TODO: figure out what service options are also allowed in ttys
  ttyOpts = { name, config, ... }: {
    options = {
      noclear = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Disables clearing the TTY after each session. Clearing the TTY when a user logs out is usually preferable.
        '';
      };

      nowait = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Disables the press `Enter to activate console` message before actually starting the `getty` program.
        '';
      };

      nologin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Disables `getty` and `/bin/login`, and gives the user a `root` (login) shell on the given TTY `device`
          immediately. Needless to say, this is a rather insecure option, but can be very useful for developer
          builds, during board bringup, or similar.
        '';
      };

      command = lib.mkOption {
        type = lib.types.nullOr program;
        default = null;
        description = ''
          Specify an external `getty`, like `agetty` or the BusyBox `getty`.
        '';
      };

      device = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
        description = ''
          Embedded systems may want to enable automatic `device` by supplying the special `@console` device. This
          works regardless weather the system uses `ttyS0`, `ttyAMA0`, `ttyMXC0`, or anything else. `finit` figures
          it out by querying sysfs: `/sys/class/tty/console/active`.
        '';
      };

      baud = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
      };

      term = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
      };
    };

    config = {
      device = lib.mkIf (config.command == null) (lib.mkDefault name);
    };
  };

  logToStr = v: if v == true then "log" else "log:${v}";

  mkConfigFile = svcType: svc: lib.concatStringsSep " " (
    (lib.singleton svcType) ++
    (lib.singleton "[${svc.runlevels}]") ++

    (lib.optional (svc.name or null != null) "name:${svc.name}") ++
    (lib.optional (svc.id or null != null) ":${svc.id}") ++
    (lib.optional (svc.restart or false != false) "restart:${toString svc.restart}") ++
    (lib.optional (svc.restart_sec or null != null) "restart_sec:${toString svc.restart_sec}") ++
    (lib.optional (svc.user or null != null) ("@${svc.user}" + lib.optionalString (svc.group != null) ":${svc.group}")) ++
    (lib.optional (svc.conditions or [ ] != [ ]) "<${lib.optionalString (svc.nohup or false) "!"}${lib.concatStringsSep "," svc.conditions}>") ++
    (lib.optional (svc.manual or false) "manual:yes") ++
    (lib.optional (svc.conflict or [ ] != [ ]) ("conflict:${lib.concatStringsSep "," svc.conflict}")) ++
    (lib.optional (svc.pid or null != null) "pid:${svc.pid}") ++
    (lib.optional (svc.type or null != null) "type:${svc.type}") ++
    (lib.optional (svc.notify or null != null) "notify:${svc.notify}") ++
    (lib.optional (svc.env or null != null) "env:${svc.env}") ++
    (lib.optional (svc.log or false != false) (logToStr svc.log)) ++
    (lib.optional (svc.pre or null != null) "pre:${svc.pre}") ++
    (lib.optional (svc.post or null != null) "post:${svc.post}") ++
    (lib.optional (svc.oncrash or null != null) "oncrash:${svc.oncrash}") ++
    (lib.optional (svc.extraConfig or "" != "") svc.extraConfig) ++
    (lib.optional (svc.command != null) svc.command) ++

    # tty specific options
    (lib.optional (svc.device or null != null) svc.device) ++
    (lib.optional (svc.baud or null != null) svc.baud) ++
    (lib.optional (svc.noclear or false) "noclear") ++
    (lib.optional (svc.nowait or false) "nowait") ++
    (lib.optional (svc.nologin or false) "nologin") ++
    (lib.optional (svc.term or null != null) svc.term) ++

    (lib.optional (svc.description != null) "-- ${svc.description}")
  );
in
{
  options.finit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      readOnly = true;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.finit;
      defaultText = lib.literalExpression "pkgs.finit";
      description = "The `finit` package to use.";
    };

    readiness = lib.mkOption {
      type = lib.types.enum [ "none" "pid" ];
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

    environment = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = ''
        Environment variables passed to *all* `finit` services.
      '';
    };

    services = lib.mkOption {
      type = with lib.types; attrsOf (submodule [ commonOpts serviceOpts ]);
      default = { };
      description = ''
        An attribute set of services, or daemons, to be monitored and automatically
        restarted if they exit prematurely.

        See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#services) for additional details.
      '';
    };

    tasks = lib.mkOption {
      type = with lib.types; attrsOf (submodule [ commonOpts serviceOpts ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to be executed by `finit`.

        See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#one-shot-commands-parallel) for additional details.
      '';
    };

    run = lib.mkOption {
      type = with lib.types; attrsOf (submodule [ commonOpts runOpts serviceOpts ]);
      default = { };
      description = ''
        An attribute set of one-shot commands to run in sequence when entering a runlevel. `run` commands
        are guaranteed to be completed before running the next command. Useful when serialization is required.

        See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#one-shot-commands-sequence) for additional details.
      '';
    };

    ttys = lib.mkOption {
      type = with lib.types; attrsOf (submodule [ commonOpts ttyOpts ]);
      default = { };
      description = ''
        An attribute set of TTYs that `finit` should manage.

        See [upstream documentation](https://github.com/troglobit/finit/tree/master/doc#ttys-and-consoles) for additional details.
      '';
    };
  };

  config = {
    # TODO: decide a reasonable default here... user can override if needed
    finit.environment.PATH = lib.makeBinPath [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      cfg.package

      # required by finit on shutdown
      pkgs.util-linux.mount

      # for finit log rotation
      pkgs.gzip
    ];

    environment.etc =
      let
        serviceTree = lib.mapAttrs' (_: service: {
          name = if service.id != null then "finit.d/available/${service.name}@.conf" else "finit.d/${service.name}.conf";
          value.text = mkConfigFile "service" service;
        }) (lib.filterAttrs (_: service: service.enable) cfg.services);

        taskTree = lib.mapAttrs' (_: task: {
          name = if task.id != null then "finit.d/available/${task.name}@.conf" else "finit.d/${task.name}.conf";
          value.text = mkConfigFile "task" task;
        }) (lib.filterAttrs (_: task: task.enable) cfg.tasks);

        run = cfg.run
          |> lib.filterAttrs (_: v: v.enable)
          |> lib.attrValues
          |> lib.sortProperties
          |> lib.concatMapStringsSep "\n" (mkConfigFile "run")
        ;

        tty = cfg.ttys
          |> lib.filterAttrs (_: v: v.enable)
          |> lib.mapAttrsToList (_: mkConfigFile "tty")
          |> (lib.concatStringsSep "\n")
        ;

        configFile = {
          "finit.conf".text = lib.mkMerge [
            (lib.mkBefore (lib.generators.toKeyValue { } cfg.environment))
            ''
              readiness ${cfg.readiness}
              runlevel ${toString cfg.runlevel}

              # ttys
              ${tty}

              # sequential one-shot commands
              ${run}
            ''
          ];
        };
      in
        lib.mkMerge [ serviceTree taskTree configFile ];

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.finit.rules = [
      "d /etc/finit.d/enabled 0755"
    ];
  };
}
