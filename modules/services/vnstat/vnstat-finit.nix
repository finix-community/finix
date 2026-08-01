{
  config,
  lib,
  ...
}:
let
  cfg = config.services.vnstat;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    finit.services.vnstat = {
      inherit (cfg) user group;

      description = "vnStat network traffic monitor";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/vnstatd " + lib.escapeShellArgs cfg.extraArgs;

      # When running in the foreground debug logs go to stdout.
      log = lib.mkDefault cfg.debug;
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/vnstat.conf" = lib.mkIf config.finit.services.vnstat.enable {
      text = lib.mkAfter ''

        # reload trigger
        # ${config.environment.etc."vnstat.conf".source}
      '';
    };
  };
}
