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
      persistent = true;
      randomDelay = true;
    };

    services.fcron.systab = lib.mapAttrsToList (
      _: t:
      let
        periodic = !t.persistent && t.interval != "minutely";
        randomDelay = t.randomDelay && t.interval != "minutely";
        options = lib.concatStringsSep "," [
          "runas(${if t.user != null then t.user else "root"})"
          "bootrun(${lib.boolToString t.persistent})"
          "random(${lib.boolToString (periodic && randomDelay)})"
          "jitter(${if !periodic && randomDelay then "255" else "0"})"
        ];

        interval =
          if t.interval == "minutely" then
            "&${options} * * * * *"
          else if t.interval == "hourly" then
            if periodic then "%hourly,${options} *" else "&${options} 0 * * * *"
          else if t.interval == "daily" then
            if periodic then "%daily,${options} * *" else "&${options} 0 0 * * *"
          else if t.interval == "weekly" then
            if periodic then "%weekly,${options} * *" else "&${options} 0 0 * * 0"
          else if t.interval == "monthly" then
            if periodic then "%monthly,${options} * * *" else "&${options} 0 0 1 * *"
          else
            throw "Unsupported fcron interval: ${t.interval}";
      in
      "${interval} ${t.command}"
    ) config.providers.scheduler.tasks;
  };
}
