{ config, pkgs, lib, ... }:
let
  cfg = config.services.fstrim;
in
{
  options.services.fstrim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    # TODO: share this type with options.providers.scheduler.tasks.*.interval
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
  };

  config = lib.mkIf cfg.enable {
    providers.scheduler.tasks = /* lib.mkIf (config.boot.isContainer != true) */ {
      fstrim = {
        inherit (cfg) interval;

        command = "${pkgs.util-linux}/bin/fstrim --listed-in /etc/fstab:/proc/self/mountinfo --verbose --quiet-unsupported";
      };
    };
  };
}
