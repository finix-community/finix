{ config, lib, ... }:
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "snooze" ];
    };
  };

  config = lib.mkIf (config.providers.scheduler.backend == "snooze") {
    providers.scheduler.supportedFeatures = {
      user = true;
    };

    programs.snooze.tasks = lib.mapAttrs (
      _: task:
      let
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

        months = [
          "jan"
          "feb"
          "mar"
          "apr"
          "may"
          "jun"
          "jul"
          "aug"
          "sep"
          "oct"
          "nov"
          "dec"
        ];
        weekdays = [
          "sun"
          "mon"
          "tue"
          "wed"
          "thu"
          "fri"
          "sat"
        ];

        # Cron format supports names for the `month` and `weekday`, convert them to ordinal for `snooze`.
        replaceNames =
          value: names:
          lib.replaceStrings names (builtins.genList (i: toString (i + 1)) (lib.length names)) (
            lib.toLower value
          );

        parseCron =
          intervals:
          let
            field = lib.elemAt intervals;
          in
          {
            minute = field 0;
            hour = field 1;
            day = field 2;
            month = replaceNames (field 3) months;
            weekday = replaceNames (field 4) weekdays;
          };

        intervals = lib.splitString " " task.interval;
        isCronFmt = builtins.length intervals == 5;
      in
      {
        inherit (task) user command;
      }
      // (
        if presets ? ${task.interval} then
          presets.${task.interval}
        else if isCronFmt then
          { schedule = parseCron intervals; }
        else
          throw "Unsupported interval format '${task.interval}'"
      )
    ) config.providers.scheduler.tasks;
  };
}
