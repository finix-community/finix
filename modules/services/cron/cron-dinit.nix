{
  config,
  lib,
  ...
}:
let
  cfg = config.services.cron;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.cron = {
      type = "process";
      command = "${lib.getExe cfg.package} -n " + lib.escapeShellArgs cfg.extraArgs;
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
