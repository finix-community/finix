{ config, lib, ... }:
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "fcron" ];
    };
  };

  config = lib.mkIf (config.providers.scheduler.backend == "fcron") {
    providers.scheduler.supportedFeatures = {
      user = true;
    };

    services.fcron.systab = lib.mapAttrsToList (
      _: v:
      let
        expr =
          if v.interval == "hourly" then
            "@${user} 1h"
          else if v.interval == "daily" then
            "@${user} 1d"
          else if v.interval == "weekly" then
            "@${user} 1w"
          else if v.interval == "monthly" then
            "@${user} 1m"
          else if v.interval == "yearly" then
            "@${user} 12m"
          else
            "&${user} ${v.interval}";

        user =
          let
            value = if v.user != null then v.user else "root";
          in
          "runas(${value})";
      in
      "${expr} ${v.command}"
    ) config.providers.scheduler.tasks;
  };
}
