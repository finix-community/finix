{
  config,
  pkgs,
  lib,
  options,
  ...
}:
let
  cfg = config.programs.podman;
in
{
  options.programs.podman = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [podman](${pkgs.podman.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.podman;
      defaultText = lib.literalExpression "pkgs.podman";
      description = ''
        The package to use for `podman`.
      '';
    };

    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to provide {command}`docker` as an alias mapping for {command}`podman`.
      '';
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        Extra packages to be made available to the {command}`podman` wrapper.
      '';
    };

    runtimes = lib.mkOption {
      type = with lib.types; listOf package;
      default = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.crun ];
      defaultText = lib.literalExpression "lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.crun ]";
    };

    prune = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to periodically prune `podman` resources.
        '';
      };

      extraArgs = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [
          "--all"
          "--volumes"
        ];
        description = ''
          Additional arguments to pass to {command}`podman system prune`. See [upstream documentation](https://docs.podman.io/en/latest/markdown/podman-system-prune.1.html)
          for additional details.
        '';
      };

      interval = lib.mkOption {
        inherit (options.providers.scheduler.interval) type description example;
        default = "weekly";
      };
    };

  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    providers.scheduler.tasks = lib.optionalAttrs cfg.prune.enable {
      podman-prune = {
        inherit (cfg.prune) interval;
        command = "${lib.getExe cfg.package} system prune --force ${toString cfg.prune.extraArgs}";
      };
    };
  };
}
