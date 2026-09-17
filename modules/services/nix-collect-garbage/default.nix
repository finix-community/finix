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
