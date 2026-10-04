{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fstrim;
in
{
  options.services.fstrim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable periodic SSD TRIM of mounted partitions in background.
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
  };

  config = lib.mkIf cfg.enable {
    providers.scheduler.tasks = # lib.mkIf (config.boot.isContainer != true)
      {
        fstrim = {
          inherit (cfg) interval;

          command = "${pkgs.util-linux}/bin/fstrim --listed-in /etc/fstab:/proc/self/mountinfo --verbose --quiet-unsupported";
        };
      };
  };
}
