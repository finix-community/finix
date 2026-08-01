{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.seatd;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    finit.services.seatd = {
      description = "seat management daemon";
      runlevels = "34";
      conditions = "service/syslogd/ready";
      notify = "s6";
      command =
        "${pkgs.seatd.bin}/bin/seatd -n %n -u root -g ${cfg.group}"
        + lib.optionalString cfg.debug " -l debug";
    };
  };
}
