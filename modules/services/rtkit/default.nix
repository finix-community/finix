{ config, pkgs, lib, ... }:
let
  cfg = config.services.rtkit;
in
{
  options.services.rtkit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rtkit;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = config.services.polkit.enable; message = "services.rtkit requires services.polkit.enable set to true"; }
    ];

    finit.services.rtkit-daemon = {
      description = "RealtimeKit scheduling policy service";
      command = "${cfg.package}/libexec/rtkit-daemon" + lib.optionalString cfg.debug " --debug";
      conditions = [ "service/dbus/ready" "service/polkit/ready" ];

      cgroup.name = "root";
    };

    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];

    users.users.rtkit = {
      isSystemUser = true;
      group = "rtkit";
      description = "RealtimeKit daemon";
    };

    users.groups.rtkit = { };
  };
}
