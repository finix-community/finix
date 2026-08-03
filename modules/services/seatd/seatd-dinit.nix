{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.seatd;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.seatd = {
      type = "process";
      command =
        "${pkgs.seatd.bin}/bin/seatd -u root -g ${cfg.group}" + lib.optionalString cfg.debug " -l debug";
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "login" ];
    };
  };
}
