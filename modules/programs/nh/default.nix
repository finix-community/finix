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
    services.nix-garbage-collect.backend = lib.mkOption {
      type = lib.types.enum [ "nh" ];
    };
    programs.nh = {
      enable = lib.mkEnableOption "nh, yet another Nix CLI helper";

      package = lib.mkPackageOption pkgs "nh" { };

      flake = lib.mkOption {
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

          The formerly valid `FLAKE` is now deprecated by nh, and will cause hard errors
          in future releases if `NH_FLAKE` is not set.

          `NH_FLAKE` can point to either a folder containing a flake, or to an outside repository containing the flake.
        '';
      };
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The string that will be used for the `NH_FILE` environment variable.

          `NH_FILE` is used by nh as the default configuration file for performing actions, such as
          `nh os switch`. This behaviour can be overriden per-command with environment variables
          that will take priority
        '';
      };
      attrp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The string that will be used for the `NH_ATTRP` environment variable.

          `NH_ATTRP` is used by nh as the default attribute for performing actions, such as
          `nh os switch`. This behaviour can be overriden per-command with environment variables
          that will take priority
        '';
      };
    };
  };
  config = {
    assertions = [
      {
        assertion = (cfg.flake != null) -> !(lib.hasSuffix ".nix" cfg.flake);
        message = "nh.flake must be a directory, or valid repository, not a nix file.";
      }
      {
        assertion = !(cfg.flake != null && cfg.file != null);
        message = "nh.file and nh.flake can not be set at the same time, they are opposite components";
      }
    ];

    environment = lib.mkIf cfg.enable {
      systemPackages = [ cfg.package ];
      variables = lib.mkMerge [
        (lib.mkIf (cfg.flake != null) { NH_FLAKE = cfg.flake; })
        (lib.mkIf (cfg.file != null) { NH_FILE = cfg.file; })
        (lib.mkIf (cfg.attrp != null) { NH_ATTRP = cfg.attrp; })
      ];
    };

    services.nix-garbage-collect = lib.mkIf (config.services.nix-garbage-collect.backend == "nh") {
      command = "${lib.getExe cfg.package} clean all ${config.services.nix-garbage-collect.extraArgs}";
    };
  };
}
