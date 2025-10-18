{ config, pkgs, lib, ... }:
let
  cfg = config.services.bluetooth;

  format = pkgs.formats.ini { };
in
{
  options.services.bluetooth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [bluez](${pkgs.bluez.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bluez;
      defaultText = lib.literalExpression "pkgs.bluez";
      description = ''
        The package to use for `bluez`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `bluez` configuration. See [upstream documentation](https://github.com/bluez/bluez/blob/master/src/main.conf)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.bluetooth.settings = {
      General = {
        ControllerMode = lib.mkDefault "dual";
      };

      Policy = {
        AutoEnable = lib.mkDefault true;
      };
    };

    environment.systemPackages = [ cfg.package ];
    environment.etc."bluetooth/main.conf".source = format.generate "main.conf" cfg.settings;

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.bluetooth = {
      description = "bluetooth service";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      command = "${cfg.package}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf" + lib.optionalString cfg.debug " -d";
    };
  };
}
