{
  config,
  lib,
  ...
}:
let
  cfg = config.services.polkit;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.polkit = {
      type = "process";
      command =
        "${cfg.package.out}/lib/polkit-1/polkitd --no-debug "
        + lib.optionalString cfg.debug "--log-level=debug";
      waits-for = [ "dbus" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
