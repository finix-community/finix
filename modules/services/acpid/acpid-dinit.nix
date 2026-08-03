{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.acpid;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.acpid = {
      type = "process";
      command = "${pkgs.acpid}/bin/acpid --foreground --netlink";
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
