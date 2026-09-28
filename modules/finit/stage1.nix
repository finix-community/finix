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
  inherit (finitFmt)
    mkBlock
    mkTitle
    mkEntries
    checkStanza
    svcSchema
    ttySchema
    ;
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

  mkStanza = type: svc: mkBlock type (mkTitle svc.name svc.id) (mkEntries svc) [ ];

  mkTtyStanza = name: svc: mkBlock "tty" (mkTitle name svc.id) (mkEntries svc) [ ];

  # every stanza with the option path it came from, for the assertions
  named =
    what: stanzas:
    lib.mapAttrsToList (name: svc: {
      path = "boot.initrd.finit.${what}.${name}";
      value = svc;
    }) (lib.filterAttrs (_: s: s.enable) stanzas);
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
    # a key finit v5 does not know takes the whole .conf file down at boot so a typo in `settings` should stop the evaluation here instead
    assertions =
      lib.concatMap
        (what: lib.concatMap (s: checkStanza s.path svcSchema s.value) (named what cfg.finit.${what}))
        [
          "services"
          "tasks"
          "run"
        ]
      ++ lib.concatMap (s: checkStanza s.path ttySchema s.value) (named "ttys" cfg.finit.ttys);

    boot.initrd.contents =
      let
        # one .conf per service and task, a `foo@` one is a %i template
        stanzaFiles =
          type: stanzas:
          map (entry: {
            target =
              if entry.value.id == "%i" then
                "/etc/finit.d/available/${entry.name}.conf"
              else
                "/etc/finit.d/${entry.name}.conf";
            source = pkgs.writeText "${entry.name}.conf" (mkStanza type entry.value);
          }) (lib.mapAttrsToList lib.nameValuePair (lib.filterAttrs (_: s: s.enable) stanzas));

        # `run` stanzas share finit.conf, they run in the order they are read
        run = lib.concatStringsSep "\n\n" (
          map (mkStanza "run") (
            lib.sortProperties (lib.concatMap (v: lib.optional v.enable v) (lib.attrValues cfg.finit.run))
          )
        );

        tty = lib.concatStringsSep "\n\n" (
          lib.filter (s: s != "") (
            lib.mapAttrsToList (name: v: if v.enable then mkTtyStanza name v else "") cfg.finit.ttys
          )
        );

        # a `script` stanza needs the generated script itself in the initramfs
        scriptFile =
          svc:
          lib.optional (svc.enable && svc.script != "") {
            source = svc.command;
          };

        scriptFiles = lib.concatLists (
          lib.mapAttrsToList (_: scriptFile) cfg.finit.tasks
          ++ lib.mapAttrsToList (_: scriptFile) cfg.finit.run
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
      ++ stanzaFiles "service" cfg.finit.services
      ++ stanzaFiles "task" cfg.finit.tasks
      ++ scriptFiles;
  };
}
