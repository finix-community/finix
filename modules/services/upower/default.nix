{ config, lib, pkgs, ... }:
let
  cfg = config.services.upower;

  format = pkgs.formats.ini { };
in
{
  options.services.upower = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable Upower, a DBus service that provides power
        management support to applications.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.upower;
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.upower = {
      description = "daemon for power management";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      command = "${cfg.package}/libexec/upowerd";
    };

    environment.etc."UPower/UPower.conf".source = format.generate "UPower.conf" cfg.settings;
  };
}
