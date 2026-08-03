{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.getty;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services = lib.genAttrs (map (dev: "getty-${dev}") cfg.ttys) (
      name:
      let
        device = lib.removePrefix "getty-" name;
        agetty = lib.getExe' (if cfg.package != null then cfg.package else pkgs.util-linux) "agetty";
      in
      {
        command = "${agetty} --noclear ${device} 38400 linux ${lib.escapeShellArgs cfg.extraArgs}";
        type = "process";
        waits-for = lib.optional config.services.mdevd.enable "mdevd-coldplug";
        restart = true;
        smooth-recovery = true;
        options = lib.optional (cfg.ttys != [ ] && device == lib.head cfg.ttys) "runs-on-console";
        targets = [ "login" ];
      }
    );
  };
}
