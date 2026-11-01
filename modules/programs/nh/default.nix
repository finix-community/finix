{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.nh;

  environment = lib.mapAttrs (
    _: v: if builtins.isBool v then (if v then "1" else "0") else toString v
  ) (lib.filterAttrs (_: v: v != null) cfg.settings);

  nh' = pkgs.writeScript "nh" ''
    #!/bin/sh
    exec ${lib.getExe' config.programs.coreutils.package "env"} \
      ${lib.escapeShellArgs (lib.mapAttrsToList (name: value: "${name}=${value}") environment)} \
      ${lib.getExe cfg.package} "$@"
  '';
in
{
  options = {
    programs.nh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable [nh](${pkgs.nh.meta.homepage}).
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nh;
        defaultText = lib.literalExpression "pkgs.nh";
        description = ''
          The package to use for `nh`.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.submodule {
          freeformType =
            with lib.types;
            attrsOf (
              nullOr (oneOf [
                str
                int
                bool
                path
              ])
            );
          options = {
            NH_FLAKE = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Preferred path/reference to a directory containing your `flake.nix` used by `NH` when running flake-based commands.
              '';
            };

            NH_OS_FLAKE = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Command-specific flake references for `os`, commands.
              '';
            };

            NH_HOME_FLAKE = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Command-specific flake references for `home`, commands.
              '';
            };

            NH_DARWIN_FLAKE = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Command-specific flake references for `darwin`, commands.
              '';
            };

            NH_FILE = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                The `nix` file and path.
              '';
            };

            NH_ATTRP = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                The `nix` attribute and path.
              '';
            };
          };
        };
        default = { };
        description = ''
          `nh` configuration. See [upstream documentation](https://github.com/nix-community/nh/tree/master/docs#environment-variables)
          for additional details.
        '';
      };

      clean = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to enable periodic garbage collection.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "weekly";
          description = ''
            The interval at which this task should run its specified {option}`command`. Accepts either a
            standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

            If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
            to the `scheduler` implementation and execute exactly as specified.

            If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
            underlying `scheduler` implementation will use its features to decide when best to run.
          '';
        };

        extraArgs = lib.mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          example = [
            "--keep"
            "5"
            "--keep-since"
            "3d"
          ];
          description = ''
            Additional arguments to pass to {command}`nh clean all`. See [upstream documentation](https://github.com/nix-community/nh/tree/master/docs#nh-clean)
            for additional details.
          '';
        };
      };

      update = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to enable automatic updates and activation of the configured flake.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = ''
            The interval at which this task should run its specified {option}`command`. Accepts either a
            standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

            If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
            to the `scheduler` implementation and execute exactly as specified.

            If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
            underlying `scheduler` implementation will use its features to decide when best to run.
          '';
        };

        extraArgs = lib.mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          example = [
            "--update-input"
            "nixpkgs"
            "github://NixOS/nixpkgs/nixos-unstable"
          ];
          description = ''
            Additional arguments to pass to {command}`nh <platform> switch --update`. See [upstream documentation](https://github.com/nix-community/nh/tree/master/docs#platform-specific-subcommands)
            for additional details.
          '';
        };

        platform = lib.mkOption {
          type = lib.types.enum [
            "os"
            "home"
            "darwin"
          ];
          default = "os";
          description = ''
            Platform to update automatically.
          '';
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.update.enable
          -> (
            cfg.settings."NH_${lib.toUpper cfg.update.platform}_FLAKE" != null
            || (cfg.settings.NH_FILE == null && cfg.settings.NH_FLAKE != null)
          );
        message = "programs.nh.update.enable requires programs.nh.settings.NH_${lib.toUpper cfg.update.platform}_FLAKE, or NH_FLAKE with NH_FILE unset.";
      }
    ];

    environment.systemPackages = [ cfg.package ];
    environment.variables = environment;

    providers.scheduler.tasks =
      lib.optionalAttrs cfg.clean.enable {
        NH_CLEAN = {
          command = "${nh'} clean all " + lib.escapeShellArgs cfg.clean.extraArgs;
          inherit (cfg.clean) interval;
        };
      }
      // lib.optionalAttrs cfg.update.enable {
        NH_UPDATE = {
          command =
            "${nh'} ${cfg.update.platform} switch --update " + lib.escapeShellArgs cfg.update.extraArgs;
          inherit (cfg.update) interval;
        };
      };
  };
}
