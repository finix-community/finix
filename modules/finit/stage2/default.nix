{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.finit;
  format = pkgs.formats.keyValue { };

  # finix-setup plugin for early boot initialization
  finix-setup = pkgs.callPackage ../../../pkgs/finix-setup {
    extraPackages = lib.unique (
      lib.flatten (
        lib.concatMap (v: lib.optional v.enable (v.packages or [ ])) (
          lib.attrValues config.boot.supportedFilesystems
        )
      )
    );
  };

  inherit (import ./types.nix { inherit lib; }) pathOrStr program rlimitsType;
  inherit (import ./render.nix { inherit lib; })
    logToStr
    cgroupToStr
    rlimitStr
    mkConfigFile
    serviceStr
    ;

  cgroupOpts = import ./options/cgroup.nix { inherit lib format; };
  runOpts = import ./options/run.nix { inherit lib; };
  oneshotOpts = import ./options/oneshot.nix { inherit lib; };
  baseOpts = import ./options/base.nix { inherit lib format; };
  execOpts = import ./options/exec.nix { inherit lib format program; };
  serviceOpts = import ./options/service.nix { inherit lib cfg program; };
  ttyOpts = import ./options/tty.nix { inherit lib program; };
  rlimitOpts = import ./options/rlimit.nix { inherit lib rlimitsType; };
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

        cgroup = lib.concatMapAttrsStringSep "\n" (
          _: cgroupOpts:
          "cgroup ${cgroupOpts.name} ${
            lib.concatMapAttrsStringSep "," (k: v: "${k}:${toString v}") cgroupOpts.settings
          }"
        ) cfg.cgroups;

        # TODO: split these out into their own files, while preserving order, and add rlimits option
        run = lib.concatMapStringsSep "\n" (serviceStr "run") (
          lib.sortProperties (lib.concatMap (v: lib.optional v.enable v) (lib.attrValues config.finit.run))
        );

        tty = lib.concatStringsSep "\n" (
          lib.concatMap (v: lib.optional v.enable (serviceStr "tty" v)) (lib.attrValues config.finit.ttys)
        );

        configFile = {
          "finit.conf".mode = "direct-symlink";
          "finit.conf".text = lib.mkMerge [
            (lib.mkBefore (lib.generators.toKeyValue { } cfg.environment))
            ''
              readiness ${cfg.readiness}
              runlevel ${toString cfg.runlevel}

              # cgroups
              ${cgroup}

              # rlimits
              ${rlimitStr cfg.rlimits}

              # ttys
              ${tty}

              # sequential one-shot commands
              ${run}
            ''
          ];
        };
      in
      lib.mkMerge [
        serviceTree
        taskTree
        sysvTree
        configFile
      ];
  };
}
