{ config, lib, ... }:
let
  cfg = config.providers.scheduler;

  anacronCompatible =
    task:
    task.persistent
    && (task.interval == "daily" || task.interval == "weekly" || task.interval == "monthly");
in
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "anacron" ];
    };
  };

  config = lib.mkIf (cfg.backend == "anacron") {
    providers.scheduler.supportedFeatures = {
      user = false;
      persistent = true;
    };

    services.cron.systab = lib.mapAttrsToList (
      _: t:
      let
        interval =
          if t.interval == "minutely" then
            "* * * * *"
          else if t.interval == "hourly" then
            "@hourly"
          else if t.interval == "daily" then
            "@daily"
          else if t.interval == "weekly" then
            "@weekly"
          else if t.interval == "monthly" then
            "@monthly"
          else
            throw "Unsupported cron interval: ${t.interval}";
        user = if t.user != null then t.user else "root";
      in
      "${interval} ${user} ${t.command}"
    ) (lib.filterAttrs (_: task: !anacronCompatible task) cfg.tasks);

    services.anacron.systab = lib.mapAttrsToList (name: t: "@${t.interval} 0 ${name} ${t.command}") (
      lib.filterAttrs (_: anacronCompatible) cfg.tasks
    );
  };
}
