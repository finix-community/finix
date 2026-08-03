{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sysklogd;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.syslogd = {
      command = "${cfg.package}/bin/syslogd -F";
      type = "process";
      restart = true;
      smooth-recovery = true;
      waits-for = [ "tmpfiles-setup" ];
      targets = [ "local" ];
    };

  };
}
