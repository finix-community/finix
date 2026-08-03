{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.earlyoom;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.earlyoom = {
      type = "process";
      command = "${cfg.package}/bin/earlyoom --syslog " + lib.escapeShellArgs cfg.extraArgs;
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
      path = lib.optionals (lib.elem "-n" cfg.extraArgs) [ pkgs.dbus ];
    };
  };
}
