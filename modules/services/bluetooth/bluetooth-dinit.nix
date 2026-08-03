{
  config,
  lib,
  ...
}:
let
  cfg = config.services.bluetooth;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.bluetooth = {
      type = "process";
      command =
        "${cfg.package}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf"
        + lib.optionalString cfg.debug " -d";
      waits-for = [ "dbus" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
    };
  };
}
