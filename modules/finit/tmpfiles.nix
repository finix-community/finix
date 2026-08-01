{
  config,
  lib,
  ...
}:
let
  cfg = config.finit.tmpfiles;
in
{
  options.finit.tmpfiles = {
    rules = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "d /tmp 1777 root root 10d" ];
      description = ''
        Rules for creation, deletion and cleaning of volatile and temporary files
        automatically. See {manpage}`tmpfiles.d(5)` for the exact format.
      '';
    };

    clean = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable automatic cleaning of temporary files.

          :::{.note}
          You must have a scheduler backend configured with
          `providers.scheduler.backend` to utilize this option.
          :::
        '';
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = ''
          The interval at which this task should run its specified {option}`command`. Accepts either a
          standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

          If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
          to the `scheduler` implementation and execute exactly as specified.

          If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
          underlying `scheduler` implementation will use its features to decide when best to run.
        '';
      };
    };
  };

  config = {
    environment.etc."tmpfiles.d/00-nixos.conf".text = ''
      # This file is created automatically and should not be modified.
      # Please change the option ‘finit.tmpfiles.rules’ instead.

      ${lib.concatStringsSep "\n" config.finit.tmpfiles.rules}
    '';

    finit.tasks.tmpfiles-setup = {
      command = "${config.finit.package}/libexec/finit/tmpfiles --create";
      reload-triggers = [
        config.environment.etc."tmpfiles.d/00-nixos.conf".source
      ];
    };

    providers.scheduler.tasks = lib.mkIf cfg.clean.enable {
      tmpfiles-clean = {
        interval = cfg.clean.interval;
        command = "${config.finit.package}/libexec/finit/tmpfiles --clean";
      };
    };

    # needed for finit tmpfiles Z implementation: pkgs.policycoreutils
    # TODO: make this an optional dependency, fixup Z behaviour in general
  };
}
