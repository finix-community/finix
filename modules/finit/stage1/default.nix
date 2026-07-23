{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;

  inherit (import ../lib/types.nix { inherit lib; }) program;
  inherit (import ./render.nix { inherit lib; }) serviceStr;

  baseOpts = import ./options/base.nix { inherit lib; };
  execOpts = import ./options/exec.nix { inherit lib program; };
  scriptOpts = import ./options/script.nix { inherit lib pkgs; };
  serviceOpts = import ./options/service.nix { inherit lib config; };
  runOpts = import ./options/run.nix { inherit lib; };
  ttyOpts = import ./options/tty.nix { inherit lib program; };
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
