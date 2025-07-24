{ lib, config, pkgs, ... }:

let
  inherit (lib)
    attrNames
    concatMap
    concatStringsSep
    escapeShellArgs
    flatten
    foldl'
    listToAttrs
    literalMD
    makeBinPath
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    optional
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

  recordOfKey = key: builtins.tail key ++ [ { _record = builtins.head key; } ];

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
          default = [ ];
          description = ''
            List of directories to compose into the PATH environmental variable.
            If `env.PATH` is set then this value is ignored. Otherwise it will be
            appended with execline and s6 packages.
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
        readyOnNotify = mkOption {
          description = ''
            When non-null enable s6 readiness notification for
            this daemon using the specified file-descriptor.
            Setting a file-descriptor here disables readyOnStart.
          '';
          type = with types; nullOr int;
          default = null;
          example = 3;
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

  loggerArgs = { reserveStdio, dir, args }:
    # Stash the original stdout if it is used for Syndicate protocol.
    optionals reserveStdio [ "fdmove" "3" "1" ] ++
    [
      "if" [ "s6-mkdir" "-p" dir ]
      # Replace stdout with s6-log.
      "pipeline" "-d" "-w"
        ([ (lib.getExe' pkgs.s6 "s6-log") ] ++ args ++ [ dir ])
    ] ++
    # If speaking the Syndicate protocol
    # then move s6-log to stderr and restore stdout to the parent
    # then duplicate the s6-log stdin to both stdout and stderr
    (if reserveStdio then [ "fdmove" "2" "1" "fdmove" "1" "3" ] else [ "fdmove" "-c" "2" "1" ])
    |> lib.quoteExecline;


  # A hack for translating s6 notifications to Syndicate protocol.
  # TODO: This adds an additional process that consumes resources
  # for the lifetime of the service. If this overhead is worthwhile then
  # s6 notification support should be added to the syndicate server
  # instead.
  readyOnNotifyArgs = fd: lib.quoteExecline [
    # Create a pipe.
    "piperw" "3" "4"
    # Run `readyonnotify` in the background with fd 1 2 3 but not 4.
    "background" [
      "fdclose" "4"
      "readyonnotify"
    ]
    # Close stdin and stdout.
    "fdclose" "0"
    "fdclose" "1"
    # Duplicate stderr onto stdout.
    "fdmove" "-c" "1" "2"
    # Move the pipe writer to the requested fd.
    "fdmove" (toString fd) "4"
    ];

  # Produce a list of Syndicate assertions from a daemon declaration.
  daemonToPreserves =
    name: attrs:
    let
      hasReadyOnNotify = attrs.readyOnNotify != null;
      protocol =
        if hasReadyOnNotify
        then assert attrs.protocol == "none"; "application/syndicate"
        else attrs.protocol;
    in [
    (<require-service> [ (<daemon> [ name ]) ])
    (<daemon> [
      name
      {
        argv =
          # Inject logging.
          optionals attrs.logging.enable (loggerArgs {
	      reserveStdio = protocol != "none";
	      inherit (attrs.logging) dir args;
	    }) ++
          # Inject notification script.
          optionals hasReadyOnNotify (readyOnNotifyArgs attrs.readyOnNotify) ++
          # Empty execline noise from environment.
          optionals (attrs.logging.enable || hasReadyOnNotify) [ "emptyenv" "-c" ] ++
          # Execute the daemon argv.
          attrs.argv
          # Double-quote the list of strings.
          # This is quoting for Preserves rather than a shell.
          |> builtins.toJSON;
        env =
          let env' = optionalAttrs (attrs.env != null) attrs.env;
          in mapAttrs (_: v: if v == null then false else builtins.toJSON v) (
            env' // {
              PATH = env'.PATH or (makeBinPath (attrs.path ++ [
                  (dirOf config.security.wrapperDir)
                  # TODO: merge into a symlink tree?
                  pkgs.execline
                  pkgs.s6
                  pkgs.s6-linux-utils
                  pkgs.s6-portable-utils
                ] ++ optional hasReadyOnNotify pkgs.syndicate_utils));
            });
        readyOnStart = attrs.readyOnStart && !hasReadyOnNotify;
        inherit (attrs) dir clearEnv restart;
        inherit protocol;
      }
    ])] ++ optional hasReadyOnNotify ''
      ? <service-object <daemon ${name}> ?obj> [
        $obj += <Observe <bind <=_>> <* $config [
          <rewrite [?s] <service-state <daemon ${name}> $s>>
        ]>>
      ]
    '';

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
      # Put files that describe core-level daemons into the core directory.
      # See ./static/boot/020-load-core-layer.pr
      map (name: let daemon = cfg.core.daemons.${name}; daeRec = <daemon> [ name ]; in {
        name = "syndicate/core/daemon-${name}.pr";
        value.source = writePreservesFile "daemon-${name}.pr" (
          (daemonToPreserves name daemon)
          ++ map
            ({ key, state }: <depends-on> [ daeRec (<service-state> [ (recordOfKey key) state ]) ])
            daemon.requires);
      }) (attrNames cfg.core.daemons)
    );

    # Accumulate `requires` and `provides` from all daemons
    # into a top-level collection.
    synit.depends = foldl' (depends: name:
      let
        daemon = cfg.daemons.${name};
        key = [ "daemon" name ];
      in
      depends
      ++ map (other: { key = other; dependee.key = key; }) daemon.provides
      ++ map (dependee: { inherit key dependee; }) daemon.requires
    ) [ ] (attrNames cfg.daemons);

    synit.profile.config = cfg.daemons
      |> attrNames |> concatMap (name: daemonToPreserves name cfg.daemons.${name});
  };

  meta = {
    maintainers = with lib.maintainers; [ ehmry ];
    # doc = ./todo.md;
  };
}
