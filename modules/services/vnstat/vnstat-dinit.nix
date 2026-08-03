{
  config,
  lib,
  ...
}:
let
  cfg = config.services.vnstat;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.vnstat = {
      type = "process";
      command = "${cfg.package}/bin/vnstatd " + lib.escapeShellArgs cfg.extraArgs;
      run-as = cfg.user;
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
