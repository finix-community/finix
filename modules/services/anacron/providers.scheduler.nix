{ config, lib, ... }:
let
  anacronCompatible =
    v:
    v.interval == "daily"
    || v.interval == "weekly"
    || v.interval == "monthly"
    || v.interval == "yearly";
in
{
  options.providers.scheduler = {
    backend = lib.mkOption {
      type = lib.types.enum [ "anacron" ];
    };
  };

  config = lib.mkIf (config.providers.scheduler.backend == "anacron") {
    providers.scheduler.supportedFeatures = {
      user = false;
    };

    services.cron.systab = lib.mapAttrsToList (
      k: v:
      let
        expr = if v.interval == "hourly" then "0 0 * * *" else v.interval;

        user = if v.user != null then v.user else "root";
      in
      "${expr} ${user} ${v.command}"
    ) (lib.filterAttrs (k: v: !anacronCompatible v) config.providers.scheduler.tasks);

    services.anacron.systab = lib.mapAttrsToList (k: v: "@${v.interval} 0 ${k} ${v.command}") (
      lib.filterAttrs (k: anacronCompatible) config.providers.scheduler.tasks
    );
  };
}
