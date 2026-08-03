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
    finit.services.earlyoom = {
      description = "early oom daemon";
      command = "${cfg.package}/bin/earlyoom --syslog " + lib.escapeShellArgs cfg.extraArgs;
      conditions = "service/syslogd/ready";
      nohup = true;

      cgroup.settings = {
        "memory.max" = "50M";
        "pids.max" = 10;
      };

      # TODO: now we're hijacking `env` and no one else can use it...
      path = lib.optionals (lib.elem "-n" cfg.extraArgs) [ pkgs.dbus ];
    };
  };
}
