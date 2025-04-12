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

    services.cron.systab = lib.mapAttrsToList (_: v:
      let
        expr =
          if v.interval == "hourly" then "0 * * * *"
          else if v.interval == "daily" then "0 0 * * *"
          else if v.interval == "weekly" then "0 0 * * 0"
          else if v.interval == "monthly" then "0 0 1 * *"
          else if v.interval == "yearly" then "0 0 1 1 *"
          else v.interval
        ;

        user =
          if v.user != null then v.user
          else "root";
      in
        "${expr} ${user} ${v.command}"
    ) config.providers.scheduler.tasks;
  };
}
