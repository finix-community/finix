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
    finit.services.acpid = {
      description = "acpi daemon";
      conditions = "service/syslogd/ready";
      command = "${pkgs.acpid}/bin/acpid --foreground --netlink";
      log = true;

      # TODO: add "if" to finit.services
      extraConfig = "if:<!int/container>";
    };
  };
}
