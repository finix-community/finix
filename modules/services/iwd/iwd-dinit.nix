{
  config,
  lib,
  ...
}:
let
  cfg = config.services.iwd;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.iwd = {
      type = "process";
      command = "${cfg.package}/libexec/iwd" + lib.optionalString cfg.debug " -d";
      waits-for =
        lib.optional config.services.dbus.enable "dbus"
        ++ lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "tmpfiles-setup" ];
      restart = true;
      smooth-recovery = true;
      log-type = "file";
      logfile = "/var/log/iwd.log";
      targets = [ "network" ];

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };
  };
}
