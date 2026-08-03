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
    finit.services.bluetooth = {
      description = "bluetooth service";
      conditions = "service/dbus/ready";
      command =
        "${cfg.package}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf"
        + lib.optionalString cfg.debug " -d";
    };
  };
}
