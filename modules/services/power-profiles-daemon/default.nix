{ config, lib, pkgs, ... }:
let
  cfg = config.services.power-profiles-daemon;
in
{
  options.services.power-profiles-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable power-profiles-daemon, a DBus daemon that allows
        changing system behavior based upon user-selected power profiles.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.power-profiles-daemon;
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.power-profiles-daemon = {
      description = "power profiles daemon";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      command = "${cfg.package}/libexec/power-profiles-daemon";
    };

    services.tmpfiles.power-profiles-daemon.rules = [
      "d /var/lib/power-profiles-daemon"
    ];
  };
}
