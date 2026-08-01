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

  execType = with lib.types; nullOr (coercedTo path toString (coercedTo program lib.getExe str));
  program = lib.types.package // {
    check = v: v.type or null == "derivation" && v ? meta.mainProgram;
  };

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
    "runlevels"
    "nohup"
    "pre"
    "post"
    "stop"
    "reload"
    "pid"
    "restart_sec"
    "supplementary_groups"
  ];

  # initrd stanzas default to the bootstrap runlevel S
  initrdDefaults = {
    config.runlevel = lib.mkDefault "S";
  };

  stanzaTitle = name: svc: if svc.id != null && svc.id != "%i" then "${svc.name}:${svc.id}" else name;

  baseOpts = { name, config, ... }: {
    freeformType = format.type;

    imports = [
      (lib.mkRenamedOptionModule [ "runlevels" ] [ "runlevel" ])
    ];

    options = {
      runlevel = lib.mkOption {
        type = with lib.types; nullOr (strMatching "!?[0-9Ss]+");
        default = null;
        description = ''
          See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
        '';
      };

      conditions = lib.mkOption {
        type = with lib.types; nullOr (coercedTo str lib.singleton (listOf str));
        default = null;
        example = "net/route/default";
        description = ''
          See [upstream documentation](https://finit-project.github.io/conditions/) for details.
        '';
      };

      command = lib.mkOption {
        type = execType;
        default = null;
        description = ''
          The command to execute.
        '';
      };

      envfile = lib.mkOption {
        type = with lib.types; nullOr (coercedTo path toString str);
        default = null;
        description = ''
          Either a path or a path prefixed with a '-' to indicate a missing file is fine.
        '';
      };

      # nix extensions
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable this stanza.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          The name of this stanza, derived from the attribute name.
        '';
      };

      id = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        readOnly = true;
        description = ''
          The instance identifier, derived from the attribute name if it contains an `@` character.
        '';
      };

      script = lib.mkOption {
        type = with lib.types; nullOr lines;
        default = null;
        description = ''
          Shell commands executed as the main process. When set, a script is
          generated and used as `command`.
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

      path = lib.mkOption {
        type = with lib.types; listOf (either package str);
        default = [ ];
        description = ''
          Packages added to the `PATH` environment variable of this service.
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

    config = lib.mkMerge [
      (lib.mkIf (config.script != null) {
        command = lib.mkForce (
          pkgs.writeScript (lib.replaceStrings [ "@" ] [ "_" ] name) ''
            #!/bin/sh
            set -eu
            ${config.script}
          ''
        );
      })
      (lib.mkIf (config.path != [ ]) {
        environment.PATH = lib.makeBinPath config.path;
      })
      (lib.mkIf (config.environment != { }) {
        envfile = lib.mkDefault (keyValue.generate "${config.name}.env" config.environment);
      })
      (
        let
          parts = lib.splitString "@" name;
        in
        {
          name = lib.head parts;
          id =
            if lib.hasSuffix "@" name then
              "%i"
            else if lib.hasInfix "@" name then
              lib.elemAt parts 1
            else
              null;
        }
      )
    ];
  };

  # options for any executable stanza: service/task/run/sysv (not tty)
  execOpts = {
    imports = [
      (lib.mkRenamedOptionModule [ "pre" ] [ "exec-start-pre" ])
      (lib.mkRenamedOptionModule [ "post" ] [ "exec-stop-post" ])
      (lib.mkRenamedOptionModule [ "supplementary_groups" ] [ "extra-groups" ])
    ];
    options = {
      exec-start-pre = lib.mkOption {
        type = execType;
        default = null;
        description = ''
          Fires before the stanza starts.
        '';
      };

      exec-stop-post = lib.mkOption {
        type = execType;
        default = null;
        description = ''
          Fires after a stanza has stopped, including after a crash.
        '';
      };

      extra-groups = lib.mkOption {
        type = with lib.types; nullOr (listOf str);
        default = null;
        description = ''
          Explicitly specify supplementary groups, in addition to reading group membership from {file}`/etc/group`.
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
    };
  };

  # options only meaningful for long-running services: service/sysv
  serviceOpts =
    { config, ... }:
    {
      imports = [
        (lib.mkRenamedOptionModule [ "stop" ] [ "exec-stop" ])
        (lib.mkRenamedOptionModule [ "reload" ] [ "exec-reload" ])
        (lib.mkRenamedOptionModule [ "pid" ] [ "pidfile" ])
        (lib.mkRenamedOptionModule [ "restart_sec" ] [ "restart-sec" ])
      ];
      options = {
        exec-stop = lib.mkOption {
          type = execType;
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

        exec-reload = lib.mkOption {
          type = execType;
          default = null;
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

        notify = lib.mkOption {
          type =
            with lib.types;
            nullOr (enum [
              "none"
              "pid"
              "systemd"
              "s6"
            ]);
          default = null;
          description = ''
            Readiness notification protocol.
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

        pidfile = lib.mkOption {
          type = with lib.types; nullOr (either bool str);
          default = null;
          description = ''
            See [upstream documentation](https://finit-project.github.io/config/services/) for details.
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

        reload-signal = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            Signal `finit` sends to reload the service, or `"none"` if the service
            does not support reload via `SIGHUP`.
          '';
        };

        # compat for finix before finit v5
        nohup = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this service supports reload on `SIGHUP`. Sets
            `reload-signal = "none"`.
          '';
        };
      };

      config.reload-signal = lib.mkIf config.nohup "none";
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
in
{
  options.finit = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.finit;
      defaultText = lib.literalExpression "pkgs.finit";
      apply =
        package:
        (package.override {
          plymouthSupport = config.programs.plymouth.enable;
          plymouth = config.programs.plymouth.package;
        }).overrideAttrs
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
      type = lib.types.attrsOf format.type;
      default = { };
      example = {
        system."cpu.weight" = 9800;
      };
      description = ''
        An attribute set of cgroups (v2) that will be created by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/cgroups/) for additional details.
      '';
    };

    rlimits = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        nofile = 300000;
      };
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
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          serviceOpts
        ]
      );
      default = { };
      description = ''
        An attribute set of services, or daemons, to be monitored and automatically
        restarted if they exit prematurely.

        See [upstream documentation](https://finit-project.github.io/config/services/) for additional details.
      '';
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
        ]
      );
      default = { };
      description = ''
        An attribute set of one-shot commands to be executed by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    run = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          runOpts
        ]
      );
      default = { };
      description = ''
        An attribute set of one-shot commands to run in sequence when entering a runlevel. `run` commands
        are guaranteed to be completed before running the next command. Useful when serialization is required.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    ttys = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          ./tty.nix
        ]
      );
      default = { };
      description = ''
        An attribute set of TTYs that `finit` should manage.

        See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
      '';
    };

    sysv = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          serviceOpts
        ]
      );
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
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          serviceOpts
          initrdDefaults
        ]
      );
      default = { };
      description = ''
        An attribute set of services, or daemons, to be monitored and automatically
        restarted if they exit prematurely.

        See [upstream documentation](https://finit-project.github.io/config/services/) for additional details.
      '';
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          initrdDefaults
        ]
      );
      default = { };
      description = ''
        An attribute set of one-shot commands to be executed by `finit`.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    run = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          runOpts
          initrdDefaults
        ]
      );
      default = { };
      description = ''
        An attribute set of one-shot commands to run in sequence when entering a runlevel. `run` commands
        are guaranteed to be completed before running the next command. Useful when serialization is required.

        See [upstream documentation](https://finit-project.github.io/config/task-and-run/) for additional details.
      '';
    };

    ttys = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          ./tty.nix
          initrdDefaults
        ]
      );
      default = { };
      description = ''
        An attribute set of TTYs that `finit` should manage.

        See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
      '';
    };

    sysv = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule [
          baseOpts
          execOpts
          serviceOpts
          initrdDefaults
        ]
      );
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
              lib.optional (svc.script != null) { source = svc.command; }
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
