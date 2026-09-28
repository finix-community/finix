{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;
  finitFmt = import ./format.nix { inherit lib pkgs; };
  inherit (finitFmt)
    mkBlock
    mkTitle
    mkEntries
    execOptsBase
    runOpts
    ttyOpts
    ;
  baseOpts = finitFmt.mkBaseOpts "S";
  execOpts =
    { name, ... }:
    {
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
    imports = [
      (lib.mkRenamedOptionModule [ "restart" ] [ "restart-max" ])
    ];

    options = {
      notify = lib.mkOption {
        type = lib.types.enum [
          "none"
          "pid"
          "s6"
        ];
        default = "none";
        description = ''
          See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
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

      respawn = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable endless restarts without counting toward the retry limit. When set, the service
          will be restarted indefinitely regardless of the `restart-max` limit.
        '';
      };
    };
  };

  mkServiceLikeBlock = svcType: svc: mkBlock svcType (mkTitle svc.name svc.id) (mkEntries svc) [ ];

  mkTtyBlock = name: svc: mkBlock "tty" name (mkEntries svc) [ ];
in
{
  options.boot.initrd.finit = {
    services = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule [
          baseOpts
          execOptsBase
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
          execOptsBase
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
          execOptsBase
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
          source = pkgs.writeText "${name}.conf" (mkServiceLikeBlock "service" service);
        }) (lib.filterAttrs (_: service: service.enable) cfg.finit.services);

        taskTree = lib.mapAttrsToList (name: task: {
          target =
            if task.id != "%i" then "/etc/finit.d/${name}.conf" else "/etc/finit.d/available/${name}.conf";
          source = pkgs.writeText "${name}.conf" (mkServiceLikeBlock "task" task);
        }) (lib.filterAttrs (_: task: task.enable) cfg.finit.tasks);

        run = lib.concatStringsSep "\n\n" (
          map (mkServiceLikeBlock "run") (
            lib.sortProperties (lib.concatMap (v: lib.optional v.enable v) (lib.attrValues cfg.finit.run))
          )
        );

        tty = lib.concatStringsSep "\n\n" (
          lib.filter (s: s != "") (
            lib.mapAttrsToList (name: v: if v.enable then mkTtyBlock name v else "") cfg.finit.ttys
          )
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
            environment {
                PATH = "/bin:/sbin:/usr/bin:/usr/local/bin"
            }

            readiness = "none"
            runlevel  = 1

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
