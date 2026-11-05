{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nix-collect-garbage;
in
{
  options.services.nix-collect-garbage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nix-collect-garbage](${pkgs.nix.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      defaultText = lib.literalExpression "pkgs.nix";
      description = ''
        The package to use for `nix-collect-garbage`.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.enum [
        "minutely"
        "hourly"
        "daily"
        "monthly"
        "weekly"
      ];
      description = ''
        The interval at which this task should run.

        The underlying {option}`providers.scheduler` implementation uses its scheduling features
        to choose an appropriate time to run within that interval.
      '';

      default = "weekly";
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "--delete-older-than" ];
      description = ''
        Additional arguments to pass to `nix-collect-garbage`. See {manpage}`nix-collect-garbage(1)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    providers.scheduler.tasks = {
      nix-collect-garbage = {
        inherit (cfg) interval;

        command = "${lib.getExe' cfg.package "nix-collect-garbage"} " + lib.escapeShellArgs cfg.extraArgs;
      };
    };
  };
}
