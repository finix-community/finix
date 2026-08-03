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
    finit.services.cron = {
      description = "cron daemon";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} -n " + lib.escapeShellArgs cfg.extraArgs;
      notify = "pid";
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/cron.conf" = lib.mkIf (config.finit.services.cron.enable) {
      text = lib.mkAfter ''

        # standard nixos trick to force a restart when something has changed
        # ${config.environment.etc.crontab.source}
      '';
    };
  };
}
