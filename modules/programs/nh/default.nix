{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nh;
in
{
  options = {
    programs.nh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable [nh](${pkgs.nh.meta.homepage}). ${pkgs.nh.meta.description}.
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
          freeformType = lib.types.attrsOf (lib.types.nullOr (lib.types.oneOf [
            lib.types.str
            lib.types.int
            lib.types.bool
            lib.types.path
          ]));

          options = {
            NH_FLAKE = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''                
                The string that will be used for the `NH_FLAKE` environment variable.

                `NH_FLAKE` is used by nh as the default flake for performing actions, such as
                `nh os switch`. This behaviour can be overriden per-command with environment
                variables that will take priority.

                - `NH_OS_FLAKE`: will take priority for `nh os` commands.
                - `NH_HOME_FLAKE`: will take priority for `nh home` commands.
                - `NH_DARWIN_FLAKE`: will take priority for `nh darwin` commands.

                `NH_FLAKE` can point to either a folder containing a flake, or to an outside repository containing the flake.
              '';
            };
            NH_OS_FLAKE = lib.mOption "settings.NH_OS_FLAKE" {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Command-specific flake references for os commands respectively. If present it takes precedence over NH_FLAKE.
              '';
              example = "github://aanderse/finix-config";
            };
            NH_HOME_FLAKE = lib.mkDefaultOption "settings.NH_HOME_FLAKE" {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Command-specific flake references for home commands respectively. If present it takes precedence over NH_FLAKE.
              '';
            };
            NH_DARWIN_FLAKE = lib.mkDefaultOption "settings.NH_DARWIN_FLAKE" {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Command-specific flake references for darwin commands respectively. If present it takes precedence over NH_FLAKE.
              '';
            };
            NH_FILE = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''                
                The string that will be used for the `NH_FILE` environment variable.

                `NH_FILE` is used by nh as the default configuration file for performing actions, such as
                `nh os switch`. This behaviour can be overriden per-command with environment variables
                that will take priority
              '';
            };
            NH_ATTRP = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''                
                The string that will be used for the `NH_ATTRP` environment variable.

                `NH_ATTRP` is used by nh as the default attribute for performing actions, such as
                `nh os switch`. This behaviour can be overriden per-command with environment variables
                that will take priority
              '';
            };
            NH_SSHOPTS = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                SSH options for remote operations. Accepts the same format as `NIX_SSHOPTS`, which it takes precedence over.
              '';
            };
            NH_SHOW_ACTIVATION_LOGS = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = ''
                Controls whether activation output is displayed. By default, activation output is hidden. Setting this to "1" will show the full activation logs, which is useful for debugging activation failures.
                Supported on all platforms (NixOS, Home Manager, and Darwin).
              '';
            };
            NH_LOG = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                Sets the tracing/log filter for NH. This uses the same format as `tracing_subscriber` env filters (for example: `nh=trace`).
              '';
            };
            NH_CONFIG = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = ''
                Overrides the path to the NH configuration file. If unset, NH uses `$XDG_CONFIG_HOME/nh/config.toml`, falling back to `~/.config/nh/config.toml`.
              '';
            };
          };
        default = { };
        description = ''
          Settings passed to nh as environment variables.
          
          See [the documentation](https://github.com/nix-community/nh/tree/master/docs#environment-variables) (or man 1 nh) for a complete list of
          available environment variables.
        '';
        };
      };

      clean = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to enable periodic garbage collection with nh clean all.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "weekly";
          description = ''
            How often cleanup is performed. Passed to providers.scheduler.task.NH_CLEAN
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "";
          example = "--keep 5 --keep-since 3d";
          description = ''
            Options given to nh clean when the service is run automatically.

            See `nh clean all --help` for more information.
          '';
        };
      };
      update = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to enable automatic updates for flake based configurations.
            Uses `nh os switch --update` by default, depends on NH_FLAKE/NH_OS_FLAKE/NH_HOME_FLAKE/NH_DARWIN_FLAKE being set.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "weekly";
          description = ''
            How often updates are performed. Passed to providers.scheduler.task.NH_UPDATE
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "";
          example = "--update-input nixpkgs github://NixOS/nixpkgs/nixos-unstable";
          description = ''
            Options to pass to the update service,
            Check `nh os switch --help` for more options
          '';
        };

        platform = lib.mkOption {
          type = lib.types.enum [ "os" "home" "darwin" ];
          default = "os";
          description = ''
            Select the platform for which to perform the auto-updating.
          '';
        };
      };
    };
  };
  config = {
    assertions = [
      {
        assertion =
          let
            flakes = with cfg.settings; [
              NH_FLAKE
              NH_OS_FLAKE
              NH_HOME_FLAKE
              NH_DARWIN_FLAKE
            ];
          in
            lib.all
              (flake: !lib.hasSuffix ".nix" flake)
              (lib.filter (flake: flake != null) flakes);

        message = "FLAKE options must be a directory, or valid repository, not a .nix file.";
      }
      {
        assertion = !((cfg.settings.NH_FLAKE != null || cfg.settings.NH_OS_FLAKE != null || cfg.settings.NH_HOME_FLAKE != null || cfg.settings.NH_DARWIN_FLAKE != null) && cfg.settings.NH_FILE != null);
        message = "NH_FILE and may FLAKE option can not be set at the same time, they are opposite components";
      }
      {
        assertion = !((cfg.settings.NH_FLAKE == null && cfg.settings.NH_OS_FLAKE == null && cfg.settings.NH_HOME_FLAKE == null && cfg.settings.NH_DARWIN_FLAKE == null) && cfg.update.enable);
        message = "The update service depends on a FLAKE option being set";
      }
    ];

    environment = lib.mkIf cfg.enable {
      systemPackages = [ cfg.package ];
      variables =
      lib.mapAttrs
        (_: v: if builtins.isBool v then (if v then "1" else "0") else toString v)
        (lib.filterAttrs (_: v: v != null) cfg.settings);
    };

    providers.scheduler.tasks = {
      NH_CLEAN = {
        command = "${lib.getExe cfg.package} clean all ${cfg.clean.extraArgs}";
        interval = "${cfg.clean.interval}";
      };
      NH_UPDATE = {
        command = "${lib.getExe cfg.package} ${cfg.update.platform} switch ${cfg.update.extraArgs}";
        interval = "${cfg.update.interval}";
      };
    };
  };
}
