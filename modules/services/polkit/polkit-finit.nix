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
    finit.services.polkit = {
      description = "policykit authorization manager";
      conditions = "service/dbus/ready";
      command =
        "${cfg.package.out}/lib/polkit-1/polkitd --no-debug "
        + lib.optionalString cfg.debug "--log-level=debug";
      notify = "systemd";
    };
  };
}
