{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.finit;
  finitOpts = import ./opts.nix { inherit lib pkgs; };
  finitFmt = import ./format.nix { inherit lib; };
  inherit (finitFmt)
    bfScalar
    mkBlock
    mkTitle
    mkEntries
    rlimitEntries
    checkStanza
    checkRlimit
    svcSchema
    ttySchema
    ;
  inherit (finitOpts)
    mkBaseOpts
    mkExecOpts
    mkServiceOpts
    execOptsBase
    oneshotOpts
    rlimitOpts
    rlimitsType
    cgroupOpts
    cgroupOpt
    runOpts
    ttyOpts
    ;
  baseOpts = mkBaseOpts "234";
  execOpts = mkExecOpts { globalPath = cfg.path; };
  serviceOpts = mkServiceOpts { readiness = cfg.readiness; };

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
    let
      entries = rlimitEntries r;
    in
    if entries == { } then null else mkBlock "rlimit" null entries [ ];

  # a whole .conf file: reload-triggers as a comment then the block itself
  mkStanza =
    type: svc:
    let
      log = logBlock svc.log;
      rlimit = rlimitBlock svc.rlimit;
    in
    lib.optionalString (
      svc.reload-triggers != [ ]
    ) "# reload-triggers = ${lib.concatStringsSep ", " svc.reload-triggers}\n\n"
    + mkBlock type (mkTitle svc.name svc.id) (mkEntries svc) (
      [ (cgroupBlock svc.cgroup) ]
      ++ lib.optional (log != null) log
      ++ lib.optional (rlimit != null) rlimit
    );

  # title = the `finit.ttys` attribute name, since `ttyOpts` has no identity of its own.
  mkTtyStanza = name: svc: mkBlock "tty" (mkTitle name svc.id) (mkEntries svc) [ ];

  named =
    what: stanzas:
    lib.mapAttrsToList (name: svc: {
      path = "finit.${what}.${name}";
      value = svc;
    }) stanzas;

  stanzas =
    lib.concatMap (what: named what cfg.${what}) [
      "services"
      "tasks"
      "run"
      "sysv"
    ];
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
    # a key finit v5 does not know takes the whole .conf file down at boot so a typo in `settings` should stop the evaluation here instead
    assertions =
      lib.concatMap (s: checkStanza s.path svcSchema s.value) stanzas
      ++ lib.concatMap (s: checkStanza s.path ttySchema s.value) (named "ttys" cfg.ttys)
      ++ (if cfg.rlimits != { } then checkRlimit "finit.rlimits" cfg.rlimits else [ ])
      ++ lib.concatMap (s: checkRlimit s.path (s.value.rlimit or { })) stanzas;

    environment.etc =
      let
        # NOTE: entries under /etc/finit.d are marked as direct-symlink to avoid service reloads on every finix activation

        # one .conf per stanza so stanzas reload one at a time.
        # NOTE: this walks the stanza attrset and touches `enable` and `id` only,
        # forcing a whole stanza would drag in `reload-triggers`, which reads etc back.
        stanzaFiles =
          type: prefix: stanzas:
          lib.mapAttrs' (
            name: svc:
            lib.nameValuePair (
              # a `foo@` stanza is a %i template instantiated from foo@bar.conf
              "finit.d/${if svc.id == "%i" then "available/" else ""}${prefix}${name}.conf"
            ) {
              mode = "direct-symlink";
              text = mkStanza type svc;
            }
          ) (lib.filterAttrs (_: s: s.enable) stanzas);

        # the index is the ordering: `run` blocks run in read order, and digits sort ahead of the service and task names
        pad = i: lib.strings.replicate (3 - lib.stringLength i) "0" + i;
        runs = stanzaFiles "run" "" (
          lib.listToAttrs (lib.imap0 (
            i: entry:
            {
              name = "${pad (toString i)}-run-${entry.name}";
              value = entry.value;
            }
          ) (lib.sortProperties (
            lib.mapAttrsToList (
              name: run: {
                inherit name;
                value = run;
                inherit (run) priority;
              }
            ) (lib.filterAttrs (_: run: run.enable) cfg.run)
          )))
        );

        cgroup = lib.concatStringsSep "\n\n" (lib.mapAttrsToList (_: cgroupBlock) cfg.cgroups);

        rlimit = rlimitBlock cfg.rlimits;

        tty = lib.concatStringsSep "\n\n" (
          lib.filter (s: s != "") (
            lib.mapAttrsToList (name: v: if v.enable then mkTtyStanza name v else "") cfg.ttys
          )
        );

        configFile = {
          "finit.conf".mode = "direct-symlink";
          "finit.conf".text = ''
            ${lib.optionalString (cfg.environment != { }) ((mkBlock "environment" null cfg.environment [ ]) + "\n")}
            readiness = ${bfScalar cfg.readiness}
            runlevel  = ${toString cfg.runlevel}

            # cgroups
            ${cgroup}

            # rlimits
            ${if rlimit == null then "" else rlimit}

            # ttys
            ${tty}
          '';
        };
      in
      lib.mkMerge [
        (stanzaFiles "service" "" cfg.services)
        (stanzaFiles "task" "" cfg.tasks)
        (stanzaFiles "sysv" "" cfg.sysv)
        runs
        configFile
      ];
  };
}
