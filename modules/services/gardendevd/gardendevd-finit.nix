{
  config,
  lib,
  ...
}:
let
  cfg = config.services.gardendevd;
in
{
  config = lib.mkIf cfg.enable {
    finit.services.gardendevd = {
      inherit (cfg) path;

      description = "device event daemon (gardendevd)";
      command = "${cfg.package}/bin/gardendevd -D %n " + lib.escapeShellArgs cfg.extraArgs;
      runlevels = "S12345789";
      cgroup.name = "init";
      notify = "s6";
      log = true;
    };

    finit.run =
      let
        defaults = {
          runlevels = "S";
          conditions = "service/gardendevd/ready";
          log = true;
          cgroup.name = "init";
          priority = 1;
        };
      in
      {
        "gardendevctl@1" = defaults // {
          description = "requesting device events";
          command = "${cfg.package}/bin/gardendevctl trigger -c add -t all";
        };
        "gardendevctl@2" = defaults // {
          description = "waiting for gardendevd to settle";
          command = "${cfg.package}/bin/gardendevctl settle -t 30";
        };
      };
  };
}
