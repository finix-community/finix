{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mdevd;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.mdevd = {
      type = "process";
      command =
        "${cfg.package}/bin/mdevd -F /run/current-system/firmware -f ${
          config.environment.etc."mdev.conf".source
        }"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      waits-for =
        lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "tmpfiles-setup" ];
      restart = true;
      smooth-recovery = true;
      log-type = "file";
      logfile = "/var/log/mdevd.log";
      targets = [ "local" ];
      path = [
        config.programs.coreutils.package
        pkgs.execline
        pkgs.kmod
        pkgs.util-linux
      ];
    };

    dinit.services.mdevd-coldplug = {
      type = "scripted";
      command =
        "${cfg.package}/bin/mdevd-coldplug"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      waits-for = [
        "mdevd"
        "tmpfiles-setup"
      ];
      log-type = "file";
      logfile = "/var/log/coldplug.log";
      targets = [ "local" ];
    };
  };
}
