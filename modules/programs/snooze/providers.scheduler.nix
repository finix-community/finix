{ config, lib, ... }:
let
  cfg = config.providers.scheduler;

  presets = {
    hourly = {
      schedule.hour = "*";
      slack = "1h";
    };
    daily.slack = "1d";
    weekly = {
      schedule.weekday = "0";
      slack = "7d";
    };
    monthly = {
      schedule.day = "1";
      slack = "28d";
    };
    yearly.schedule.day_of_year = "1";
  };

  scheduleFrom =
    interval:
    let
      field = lib.elemAt lib.splitString " " interval;
    in
    {
      schedule = {
        minute = field 0;
        hour = field 1;
        day = field 2;
        month = field 3;
        weekday = field 4;
      };
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
    };

    programs.snooze.tasks = lib.mapAttrs (
      _: task:
      {
        inherit (task) user command;
      }
      // (presets.${task.interval} or (scheduleFrom task.interval))
    ) cfg.tasks;
  };
}
