{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.atd;
in
{
  config = lib.mkIf cfg.enable {
    finit.services.atd = {
      description = "deferred execution scheduler";
      conditions = "service/syslogd/ready";
      command = "${pkgs.at}/bin/atd -f " + lib.escapeShellArgs cfg.extraArgs;
      notify = "pid";
    };
  };
}
