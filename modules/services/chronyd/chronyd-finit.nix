{
  config,
  lib,
  ...
}:
let
  cfg = config.services.chrony;
  notifySupport = lib.versionAtLeast cfg.package.version "4.9";
in
{
  config = lib.mkIf cfg.enable {
    finit.services.chronyd = {
      description = "chrony ntp daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/chronyd " + lib.escapeShellArgs cfg.extraArgs;
      nohup = true;
      notify = lib.mkIf notifySupport "s6";

      # TODO: add "if" to finit.services
      extraConfig = "if:<!int/container>";
    };
  };
}
