defaultPackage:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nncp;

  inherit (lib) concatMapStrings getExe types;
  writeExeclineScript = pkgs.execline.passthru.writeScript;

  nncpCfgFile = "/run/nncp.hjson";
  settingsFormat = pkgs.formats.json { };
  jsonCfgFile = settingsFormat.generate "nncp.json" cfg.settings;

  extraArgs = lib.mkOption {
    type = with types; listOf str;
    description = "Extra command-line arguments .";
    default = [ ];
  };

  configScript = writeExeclineScript "nncp-config.el" [ ] ''
    importas -S PATH
    export PATH "${
      lib.makeBinPath [
        cfg.package
        pkgs.jq
        pkgs.hjson-go
      ]
    }:$PATH"
    umask 127
    foreground { s6-rmrf ${nncpCfgFile} }
    pipeline -r {
      forx -E f { ${jsonCfgFile} ${toString cfg.secrets} }
        redirfd -r 0 $f
        hjson-cli -c
    }
    if {
      redirfd -w 1 ${nncpCfgFile}
      # Combine and remove neighbors that would clash with the self identity.
      jq --slurp --sort-keys
        "reduce .[] as $x ({}; . * $x) | .neigh.self as $self | del(.neigh [] | select(.id == $self.id) | select(. != $self))"
    }
    s6-envuidgid -n root:${cfg.group}
    s6-chown -U ${nncpCfgFile}
  '';
in
{
  _class = "service";
  options.nncp = {

    group = lib.mkOption {
      type = lib.types.str;
      default = "uucp";
      description = ''
        The group under which NNCP files shall be owned.
        Any member of this group may access the secret keys
        of this NNCP node.
      '';
    };

    package = lib.mkPackageOption pkgs "nncp" { } // {
      default = defaultPackage;
    };

    secrets = lib.mkOption {
      type = with lib.types; listOf str;
      example = [ "/run/keys/nncp.hjson" ];
      description = ''
        A list of paths to NNCP configuration files that should not be
        in the Nix store. These files are layered on top of the values from `settings`.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      description = ''
        NNCP configuration, see
        <http://www.nncpgo.org/Configuration.html>.
        At runtime these settings will be overlayed by the contents of
        `secrets` into the file
        `${nncpCfgFile}`. Node keypairs go in
        `secrets`, do not specify them in
        `settings` as they will be leaked into
        `/nix/store`!
      '';
      default = { };
    };

    callers = lib.mkOption {
      description = "NNCP caller daemon";
      default = { };
      type =
        with types;
        attrsOf (submodule {
          options = {
            inherit extraArgs;
          };
        });
    };

    daemons = lib.mkOption {
      description = "NNCP TCP listening daemons";
      default = { };
      example = {
        ipv4.ucspi = {
          enable = true;
          addr = "0.0.0.0";
        };
        ipv6.ucspi = {
          enable = true;
          addr = "::";
        };
      };
      type =
        with types;
        attrsOf (submodule {
          options = {
            ucspi = {
              enable = lib.mkEnableOption ''
                socket activation via the UNIX Client-Server Program Interface
              '';
              addr = lib.mkOption {
                type = types.str;
              };
              port = lib.mkOption {
                type = types.port;
                default = 5400;
              };
              inherit extraArgs;
            };
            inherit extraArgs;
          };
        });
    };

  };

  config = {

    nncp.settings = {
      spool = lib.mkDefault "/var/spool/nncp";
      log = lib.mkDefault "/var/spool/nncp/log";
    };

    process.argv = [ configScript ];
    synit.daemon = {
      restart = "on-error";
      logging.enable = lib.mkDefault false;
    };

    services = lib.mkMerge [
      (lib.mapAttrs' (
        name:
        { extraArgs, ... }:
        {
          name = "caller-${name}";
          value.process.argv = [
            "s6-envuidgid"
            "root"
            "s6-envuidgid"
            "-g"
            cfg.group
            "s6-applyuidgid"
            "-U"
            "emptyenv"
            "${cfg.package}/bin/nncp-caller"
            "-cfg"
            nncpCfgFile
          ]
          ++ extraArgs;
        }
      ) cfg.callers)

      (lib.mapAttrs' (
        name:
        { ucspi, extraArgs, ... }:
        {
          name = "daemon-${name}";
          value.process.argv =
            lib.optionals ucspi.enable (
              [
                "s6-envuidgid"
                "root"
                "s6-envuidgid"
                "-g"
                cfg.group
                "${lib.getExe' pkgs.s6-networking "s6-tcpserver"}"
                "-U"
              ]
              ++ ucspi.extraArgs
              ++ [
                ucspi.addr
                (toString ucspi.port)
              ]
            )
            ++ [
              "emptyenv"
              "${cfg.package}/bin/nncp-daemon"
              "-cfg"
              nncpCfgFile
            ]
            ++ lib.optional ucspi.enable "-ucspi"
            ++ extraArgs;
        }
      ) cfg.daemons)
    ];

  };
}
