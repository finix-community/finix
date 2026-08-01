{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.mdevd;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    finit.services.mdevd = {
      description = "device event daemon (mdevd)";
      command =
        "${cfg.package}/bin/mdevd -D %n -F /run/current-system/firmware -f ${
          config.environment.etc."mdev.conf".source
        }"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      runlevels = "S12345789";
      cgroup.name = "init";
      notify = "s6";
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      path = [
        config.programs.coreutils.package
        pkgs.execline
        pkgs.kmod
        pkgs.util-linux
      ];
    };

    finit.run.coldplug = {
      description = "cold plugging system";
      command =
        "${cfg.package}/bin/mdevd-coldplug"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      runlevels = "S";
      conditions = "service/mdevd/ready";
      cgroup.name = "init";
      log = true;
    };
  };
}
