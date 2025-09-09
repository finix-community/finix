{ lib, config, pkgs, ... }:

let
  inherit (builtins) any length toJSON;
  inherit (lib)
    attrNames
    concatMap
    concatStringsSep
    foldl'
    listToAttrs
    literalMD
    getExe'
    makeBinPath
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    optional
    optionals
    optionalAttrs
    quoteExecline
    types
    ;

  strOrPath = with types; either str path;

  preserves = pkgs.sampkgs.formats.preserves {
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
            default = [ "t" ];
            description = ''
              Command-line arguments passed to s6-log before the logging directory.
              The default arguments prepend logged lines with a
              [TAI64N](https://skarnet.org/software/skalibs/libstddjb/tai.html) timestamp.
              Override args to `[ ]` if this information would be redundant.
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

        persistent = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether this daemon should persist and never
            be replaced or removed.
          '';
        };

        syd = {
          enable = mkEnableOption "Syd sandboxing";
          allowPackages = mkOption {
            description = ''
              List of Nix store paths that can be read or executed.
            '';
          };
          profiles = mkOption {
            description = ''
              List of predefined Syd profiles to apply.
              See `syd(5)` for list of common profiles.
            '';
            type = with types; listOf str;
            default = [ ];
            example = [ "readonly" "nomem" ];
          };
          rules = mkOption {
            description = "Syd sandboxing commands.";
            type = types.lines;
            example = ''
              allow/read+/etc/secrets/foo
              allow/net/bind+127.0.0.1!8080
            '';
          };
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
        ([ "s6-log" ] ++ args ++ [ dir ])
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

  # Generate a Syd profile.
  sydProfile = name: { allowPackages, rules, ... }:
    pkgs.runCommand "${name}.syd-3" {
      exportReferencesGraph = foldl'
        (acc: p: acc ++ [ "graph.${acc |> length |> toString}" p])
        [] allowPackages;
    } ''
      cat graph.* | sort -u | awk '/nix\/store/ {
          print "allow/exec,read,stat+" $1 "/***"
        }' >>$out
      cat << EOF >> $out
      ${rules}

      EOF
    '';

  # Produce a list of Syndicate assertions from a daemon declaration.
  daemonToPreserves =
    name: attrs:
    let
      hasReadyOnNotify = attrs.readyOnNotify != null;
      protocol =
        if hasReadyOnNotify
        then assert attrs.protocol == "none"; "application/syndicate"
        else attrs.protocol;
      attrs' =
      {
        argv =
          [ "s6-setlock" "/run/synit/locks/daemon-${name}" ] ++
          # Inject logging.
          optionals attrs.logging.enable (loggerArgs {
	      reserveStdio = protocol != "none";
	      inherit (attrs.logging) dir args;
	    }) ++
          # Inject notification script.
          optionals hasReadyOnNotify (readyOnNotifyArgs attrs.readyOnNotify) ++
          # Empty execline noise from environment.
          optionals (attrs.logging.enable || hasReadyOnNotify) [ "emptyenv" "-c" ] ++
          optionals (attrs.logging.enable || hasReadyOnNotify) [ "emptyenv" "-c" ] ++
          optionals (attrs.logging.enable && attrs.syd.enable) (quoteExecline [
            "fdreserve" "1"
            "importas" "-i" "SYD_LOG_FD" "FD0"
            "fdmove" "$SYD_LOG_FD" "1"
            "pipeline" "-w" ([ "s6-log" ] ++ attrs.logging.args ++ [ "${attrs.logging.dir}.syd" ])
            "fdswap" "1" "$SYD_LOG_FD"
            "export" "SYD_LOG_FD" "$SYD_LOG_FD"
          ]) ++
          optionals (attrs.syd.enable) (
            let
              cmd =
                [ "${pkgs.sydbox}/bin/syd" "-pnopie" ] ++
                (map (p: "-p${p}") attrs.syd.profiles) ++
                [
                  "-P${sydProfile name attrs.syd}"
                  "-mlock:on"
                  "--"
                ];
            in
            if (any (w: w == "$SYD") attrs.argv)
            # Replace $SYD within the argv,
            # presumably after some setup commands.
            then [ "define" "-s" "SYD" (concatStringsSep "\n" cmd) ]
            # Prepend argv with Syd.
            else cmd
          ) ++
          # Execute the daemon argv.
          attrs.argv
          # Double-quote the list of strings.
          # This is quoting for Preserves rather than a shell.
          |> builtins.toJSON;
        env =
          let
            env' = optionalAttrs (attrs.env != null) attrs.env;
            path' = attrs.path ++ optional hasReadyOnNotify pkgs.sampkgs.syndicate-utils;
          in mapAttrs (_: v: if v == null then false else toJSON v) (
            env' // lib.optionalAttrs (path' != []) {
              PATH = env'.PATH or "${makeBinPath path'}:${config.synit.basePath}";
            });
        readyOnStart = attrs.readyOnStart && !hasReadyOnNotify;
        inherit (attrs) dir clearEnv restart;
        inherit protocol;
      };
      daemonAssertions = [
        (<daemon> [ name attrs' ])
      ] ++ optional hasReadyOnNotify ''
        ? <service-object <daemon ${name}> ?obj> [
          $obj += <Observe <bind <=_>> <* $config [
            <rewrite [?s] <service-state <daemon ${name}> $s>>
          ]>>
        ]
      '';
    in
    [ (<require-service> [ (<daemon> [ name ]) ]) ] ++
        (if attrs.persistent
        then
          # Symlinks the daemon definition into the persistent
          # config directory when the daemon is requested to start.
          [ ''
            ? <run-service <daemon ${name}>> [
              ! <exec ${
                let dst = "/run/synit/config/persistent/daemon-${name}.pr"; in [
                "if" "-t" "-n" [
                  "eltest" "-e" dst
                ]
                "s6-ln" "-s"
                  (writePreservesFile "daemon-${name}" daemonAssertions)
                  dst
              ] |> lib.quoteExecline |> toJSON }>
            ]
          '' ]
        else daemonAssertions);

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
      map (label: let daemon = cfg.core.daemons.${label}; in
        rec {
          name = "syndicate/core/${value.source.name}";
          value.source = writePreservesFile "daemon-${label}" (
            (daemonToPreserves label daemon)
            ++ map
              ({ key, state }: <depends-on> [ (<daemon> [ label ]) (<service-state> [ (recordOfKey key) state ]) ])
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

    synit.plan.config = mapAttrs' (name: value: {
        name = "daemon-${name}"; value = daemonToPreserves name value;
      }) cfg.daemons;
  };

  meta = {
    maintainers = with lib.maintainers; [ ehmry ];
    # doc = ./todo.md;
  };
}
