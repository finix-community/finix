{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;
  finitOpts = import ./opts.nix { inherit lib pkgs; };
  finitFmt = import ./format.nix { inherit lib; };
  inherit (finitFmt) mkBlock mkTitle mkEntries;
  inherit (finitOpts)
    mkBaseOpts
    execOptsBase
    mkInitrdExecOpts
    mkServiceOpts
    runOpts
    ttyOpts
    ;
  baseOpts = mkBaseOpts "S";
  execOpts = mkInitrdExecOpts;
  serviceOpts = mkServiceOpts {
    readiness = "none";
    nohup = false;
    notify = [
      "none"
      "pid"
      "s6"
    ];
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
