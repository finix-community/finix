{
  config,
  pkgs,
  lib,
  options,
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
      inherit (options.providers.scheduler.interval) type description example;
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
