{ lib, config, pkgs, ... }:

let
  inherit (lib)
    attrNames
    escapeShellArgs
    foldl'
    listToAttrs
    literalMD
    makeBinPath
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    optionals
    optionalAttrs
    types
    ;

  strOrPath = with types; either str path;

  preserves = pkgs.formats.preserves {
    ignoreNulls = true;
    rawStrings = true;
  };

  writePreservesFile = preserves.generate;

  # Sugar for creating records with < >.
  inherit (preserves) __findFile;

  writeExeclineScript = pkgs.execline.passthru.writeScript;

  # Create a logging wrapper for some arguments and a directory.
  # This could be decomposed further to a list of command-line
  # arguments without calling execlineb.
  makeLogger = args: dir: [
    (writeExeclineScript "logger.el" "-s1" ''
      if { ${lib.getExe' pkgs.s6-portable-utils "s6-mkdir"} -p "$1" }
      fdswap 1 2
      pipeline -w { ${lib.getExe' pkgs.s6 "s6-log"} ${escapeShellArgs args} "$1" }
      fdswap 1 2
      $@
    '')
    dir
  ];

  cfg = config.synit;

  mkIfSynit = mkIf cfg.enable;

  daemonSubmodule = types.submodule (
    { name, ... }:
    {
      options = {
        argv = mkOption {
          description = ''
            Daemon command line.
            A string is executed in a shell whereas a list of strings is executed directly.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#adding-process-specifications-to-a-service).
          '';
          type = with types; either strOrPath (listOf strOrPath);
        };
        clearEnv = mkOption {
          description = ''
            Whether the Unix process environment is cleared or inherited.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#specifying-subprocess-environment-variables).
          '';
          type = types.bool;
          default = false;
        };
        dir = mkOption {
          description = ''
            Sets the working direcctory of a daemon.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#setting-the-current-working-directory-for-a-subprocess).
          '';
          type = with types; nullOr str;
          default = null;
        };
        env = mkOption {
          description = ''
            Sets Unix process environment for a daemon.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#specifying-subprocess-environment-variables).
          '';
          type = with types; nullOr (attrsOf str);
          default = null;
        };
        path = mkOption {
          type =
            with types;
            listOf (oneOf [
              str
              path
              package
            ]);
          default = [ pkgs.coreutils ];
          defaultText = literalMD "{option}`config.security.wrapperDir` and GNU coreutils";
          description = ''
            List of directories to compose into the PATH environmental variable.
          '';
        };
        protocol = mkOption {
          description = ''
            Specify a protocol for communicating with a daemon over stdin and stdout.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#speaking-syndicate-network-protocol-via-stdinstdout).
          '';
          type = types.enum [
            "none"
            "application/syndicate"
            "text/syndicate"
          ];
          default = "none";
        };
        readyOnStart = mkOption {
          description = ''
            Whether a daemon should be considered ready immediately after startup.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#ready-signalling).
          '';
          type = types.bool;
          default = true;
        };
        restart = mkOption {
          description = ''
            Daemon restart policy.
            See [
              https://synit.org/book/operation/builtin/daemon.html
            ](https://synit.org/book/operation/builtin/daemon.html#whether-and-when-to-restart).
          '';
          type = types.enum [
            "always"
            "on-error"
            "all"
            "never"
          ];
          default = "always";
        };

        logging = {
          enable = (mkEnableOption "inject a logging wrapper over this daemon") // {
            default = config.synit.logging.logToFileSystem;
            defaultText = literalMD "config.synit.logging.logToFileSystem";
          };
          args = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Command-line arguments passed to s6-log before the logging directory.
            '';
          };
          dir = mkOption {
            type = types.path;
            defaultText = literalMD "/var/log/${name}";
            default = "/var/log/${name}";
            description = ''
              Directory for log files from this daemon.
            '';
          };
        };

        requires = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                key = mkOption {
                  type = types.listOf types.str;
                  description = ''
                    Label of a service.
                    The head of the list is the record label and the tail is the fields.
                  '';
                };
                state = mkOption {
                  type = types.str;
                  default = "up";
                  description = "Required service state.";
                };
              };
            }
          );
          default = [ ];
          description = ''
            Services required this daemon.
            It is a list of `{ key, state }` attrs where `key` identifies
            a service and `state` is a service state.a
          '';
          example = [
            {
              key = [ "milestone" "foo" ];
              state = "up";
            }
            {
              key = [ "daemon" "oneshot-script" ];
              state = "complete";
            }
          ];
        };
        provides = mkOption {
          type = with types; listOf (listOf str);
          default = [ ];
          description = ''
            Reverse requires of this daemon.
            It is a list of service keys.
          '';
          example = [
            [ "milestone" "network" ]
          ];
        };
      };
    }
  );

  daemonToPreserves =
    name: attrs:
    <daemon> [
      name
      {
        argv = builtins.toJSON (
          optionals attrs.logging.enable (
            makeLogger attrs.logging.args attrs.logging.dir
            ++ optionals (attrs.protocol == "none") [ "fdmove" "-c" "1" "2" ])
          ++ attrs.argv
        );
        env =
          let env' = optionalAttrs (attrs.env != null) attrs.env;
          in mapAttrs (_: v: if v == null then false else builtins.toJSON v) (
            env' // {
              PATH = env'.PATH or "${config.security.wrapperDir}:${makeBinPath attrs.path}";
            });
        inherit (attrs)
          dir
          clearEnv
          readyOnStart
          restart
          protocol
          ;
      }
    ];

in
{
  options.synit = {
    core = {
      daemons = mkOption {
        description = ''
          Definitions of daemons to assert as Synit core services.
          For each daemon defined in core a `<requires-service <daemon ''${name}>>`
          assertion is also made.
        '';
        default = { };
        type = types.attrsOf daemonSubmodule;
      };
    };

    daemons = mkOption {
      description = ''
        Definitions of daemons to assert into the Synit configuration dataspace.";
      '';
      default = { };
      type = types.attrsOf daemonSubmodule;
    };

  };

  config = mkIfSynit {

    environment.etc = listToAttrs (
      map (name: {
        name = "syndicate/core/daemon-${name}.pr";
        value.source = writePreservesFile "daemon-${name}.pr" ([
          (<require-service> [ (<daemon> [ name ]) ])
          (daemonToPreserves name cfg.core.daemons.${name})
        ]);
      }) (attrNames cfg.core.daemons)
      ++ map (name: {
        name = "syndicate/services/daemon-${name}.pr";
        value.source = writePreservesFile "daemon-${name}.pr" [
          (daemonToPreserves name cfg.daemons.${name})
        ];
      }) (attrNames cfg.daemons)
    );

    synit.depends = foldl' (depends: name:
      let
        daemon = cfg.daemons.${name};
        key = [ "daemon" name ];
      in
      depends
      ++ map (other: { key = other; dependee.key = key; }) daemon.provides
      ++ map (dependee: { inherit key dependee; }) daemon.requires
    ) [ ] (attrNames cfg.daemons);

  };

  meta = {
    maintainers = with lib.maintainers; [ ehmry ];
    # doc = ./todo.md;
  };
}
