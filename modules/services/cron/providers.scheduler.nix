{ config, lib, ... }:
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "cron" ];
    };
  };

  config = lib.mkIf (config.providers.scheduler.backend == "cron") {
    providers.scheduler.supportedFeatures = {
      user = true;
    };

    services.cron.systab = lib.mapAttrsToList (
      _: task:
      let
        interval =
          if task.interval == "minutely" then
            "* * * * *"
          else if task.interval == "hourly" then
            "@hourly"
          else if task.interval == "daily" then
            "@daily"
          else if task.interval == "weekly" then
            "@weekly"
          else if task.interval == "monthly" then
            "@monthly"
          else
            throw "Unsupported cron interval: ${task.interval}";
        user = if task.user != null then task.user else "root";
      in
      "${interval} ${user} ${task.command}"
    ) config.providers.scheduler.tasks;
  };
}
