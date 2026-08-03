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
    dinit.services.atd = {
      type = "process";
      command = "${pkgs.at}/bin/atd -f " + lib.escapeShellArgs cfg.extraArgs;
      waits-for = lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd";
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
