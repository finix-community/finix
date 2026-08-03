{
  config,
  lib,
  ...
}:
let
  cfg = config.services.chrony;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.chronyd = {
      type = "process";
      command = "${cfg.package}/bin/chronyd " + lib.escapeShellArgs cfg.extraArgs;
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
