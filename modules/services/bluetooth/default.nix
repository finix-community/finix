{ config, pkgs, lib, ... }:
let
  cfg = config.services.bluetooth;
in
{
  options.services.bluetooth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bluez;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.bluetooth = {
      description = "bluetooth service";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      command = "${cfg.package}/bin/bluetoothd" + lib.optionalString cfg.debug " -d";
    };
  };
}
