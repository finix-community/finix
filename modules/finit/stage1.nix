{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;

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

  # baseOpts: options shared by ALL stanza types (service, task, run, tty)
  baseOpts = {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable this stanza.
        '';
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

      runlevels = lib.mkOption {
        type = lib.types.str; # TODO: string  matching 0-9S
        default = "S";
        description = ''
          See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
        '';
      };
    };
  };

  # execOpts: options shared by executable stanzas (service, task, run) but NOT tty
  execOpts =
    { name, ... }:
    {
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

        command = lib.mkOption {
          type = program;
          description = ''
            The command to execute.
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
      };

      config = {
        name = lib.head (lib.splitString "@" name);
        id = if lib.hasInfix "@" name then lib.elemAt (lib.splitString "@" name) 1 else null;
      };
    };

  # scriptOpts: `script` convenience option for task and run stanzas only
  scriptOpts =
    { name, config, ... }:
    {
      options.script = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Shell commands executed as the main process.
        '';
      };

      config = lib.mkIf (config.script != "") {
        command = lib.mkForce (
          pkgs.writeScript (lib.replaceStrings [ "@" ] [ "_" ] name) ''
            #!/bin/sh
            set -eu
            ${config.script}
          ''
        );
      };
    };

  # serviceOpts: options specific to service stanzas only
  serviceOpts = {
    options = {
      notify = lib.mkOption {
        type = lib.types.enum [
          "none"
          "pid"
          "s6"
        ];
        default = config.finit.readiness;
        defaultText = lib.literalExpression "config.finit.readiness";
        description = ''
          See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
        '';
      };

      restart = lib.mkOption {
        type = with lib.types; nullOr (ints.between (-1) 255);
        default = null;
        description = ''
          The number of times `finit` tries to restart a crashing service. When
          this limit is reached the service is marked crashed and must be restarted
          manually with `initctl restart NAME`. When `null`, finit's built-in
          default applies.
        '';
      };

      respawn = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable endless restarts without counting toward the retry limit. When set, the service
          will be restarted indefinitely regardless of the `restart` limit.
        '';
      };
    };
  };

  # runOpts: options specific to run stanzas
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

  # ttyOpts: options specific to tty stanzas
  ttyOpts =
    { name, config, ... }:
    {
      options = {
        device = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            Embedded systems may want to enable automatic `device` by supplying the special `@console` device. This
            works regardless weather the system uses `ttyS0`, `ttyAMA0`, `ttyMXC0`, or anything else. `finit` figures
            it out by querying sysfs: `/sys/class/tty/console/active`.
          '';
        };

        command = lib.mkOption {
          type = with lib.types; nullOr program;
          default = null;
          description = ''
            Specify an external `getty`, like `agetty` or the BusyBox `getty`.
          '';
        };

        baud = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            Baud rate for serial TTYs.
          '';
        };

        term = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            The `TERM` environment variable value for the TTY.
          '';
        };

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

        rescue = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Start `sulogin` instead of a regular shell, requiring the root password. Useful for rescue/single-user mode.
          '';
        };

        notty = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            No device node mode. This is insecure and intended only for board bringup or testing scenarios.
          '';
        };
      };

      config.device = lib.mkIf (config.command == null) (lib.mkDefault name);
    };

  serviceStr =
    svcType: svc:
    lib.concatStringsSep " " (
      [
        svcType
        "[${svc.runlevels}]"
      ]
      ++ lib.optional (svc.name or null != null) "name:${svc.name}"
      ++ lib.optional (svc.id or null != null) ":${svc.id}"
      ++ lib.optional (svc.respawn or false) "respawn"
      ++ lib.optional (svc.restart or null != null) "restart:${toString svc.restart}"
      ++ lib.optional (svc.notify or null != null) "notify:${svc.notify}"
      ++ lib.optional (svc.conditions or [ ] != [ ]) "<${lib.concatStringsSep "," svc.conditions}>"
      ++ lib.optional (svc.tty or null != null) "tty:${svc.tty}"
      ++ lib.optional (svc.extraConfig or "" != "") svc.extraConfig
      ++ lib.optional (svc.command or null != null) svc.command
      ++

        # tty specific options
        (lib.optional (svc.device or null != null) svc.device)
      ++ lib.optional (svc.baud or null != null) svc.baud
      ++ lib.optional (svc.noclear or false) "noclear"
      ++ lib.optional (svc.nowait or false) "nowait"
      ++ lib.optional (svc.nologin or false) "nologin"
      ++ lib.optional (svc.rescue or false) "rescue"
      ++ lib.optional (svc.notty or false) "notty"
      ++

        (lib.optional (svc.description != null) "-- ${svc.description}")
    );
in
{
  options.boot.initrd.finit = {
    services = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOpts
          serviceOpts
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
          scriptOpts
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
          runOpts
          scriptOpts
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
  };

  config = {
    boot.initrd.contents =
      let
        serviceTree = lib.mapAttrsToList (name: service: {
          target =
            if service.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = pkgs.writeText "${name}.conf" (serviceStr "service" service);
        }) (lib.filterAttrs (_: service: service.enable) cfg.finit.services);

        taskTree = lib.mapAttrsToList (name: task: {
          target =
            if task.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = pkgs.writeText "${name}.conf" (serviceStr "task" task);
        }) (lib.filterAttrs (_: task: task.enable) cfg.finit.tasks);

        run = lib.concatMapStringsSep "\n" (serviceStr "run") (
          lib.sortProperties (lib.concatMap (v: lib.optional v.enable v) (lib.attrValues cfg.finit.run))
        );

        tty = lib.concatStringsSep "\n" (
          lib.concatMap (v: lib.optional v.enable (serviceStr "tty" v)) (lib.attrValues cfg.finit.ttys)
        );

        mkScriptFile =
          _: svc:
          lib.optional (svc.enable && svc.script != "") {
            source = svc.command;
          };

        scriptFiles = lib.concatLists (
          lib.mapAttrsToList mkScriptFile cfg.finit.tasks ++ lib.mapAttrsToList mkScriptFile cfg.finit.run
        );
      in
      [
        {
          target = "/etc/finit.conf";
          source = pkgs.writeText "finit.conf" ''
            PATH=/bin:/sbin:/usr/bin:/usr/local/bin

            readiness none
            runlevel 1

            # ttys
            ${tty}

            # sequential one-shot commands
            ${run}
          '';
        }
      ]
      ++ serviceTree
      ++ taskTree
      ++ scriptFiles;
  };
}
