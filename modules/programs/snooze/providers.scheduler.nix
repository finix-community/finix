{ config, lib, ... }:
let
  cfg = config.providers.scheduler;

  presets = {
    minutely.schedule = {
      hour = "*";
      minute = "*";
    };
    hourly = {
      schedule.hour = "*";
      timing.slack = "1h";
    };
    daily.timing.slack = "1d";
    weekly = {
      schedule.weekday = "0";
      timing.slack = "7d";
    };
    monthly = {
      schedule.day = "1";
      timing.slack = "28d";
    };
    yearly.schedule.day_of_year = "1";
  };
in
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "snooze" ];
    };
  };

  config = lib.mkIf (cfg.backend == "snooze") {
    providers.scheduler.supportedFeatures = {
      user = true;
      persistent = true;
      randomDelay = true;
    };

    programs.snooze.tasks = lib.mapAttrs (
      _: task:
      {
        inherit (task) user command;
        timing.jitter = task.randomDelay;
      }
      // lib.optionalAttrs (!task.persistent) { timeFile = null; }
      // (presets.${task.interval})
    ) cfg.tasks;
  };
}
