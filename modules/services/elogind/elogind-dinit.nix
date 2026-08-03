{
  config,
  lib,
  ...
}:
let
  cfg = config.services.elogind;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.elogind = {
      type = "process";
      command = "${cfg.package}/libexec/elogind";
      waits-for = [ "dbus" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
