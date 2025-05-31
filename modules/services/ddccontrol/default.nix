{ config, pkgs, lib, ... }:
let
  cfg = config.services.ddccontrol;
in
{
  options.services.ddccontrol = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "i2c_dev" ];

    environment.systemPackages = [
      pkgs.ddccontrol
    ];

    services.dbus.packages = [
      pkgs.ddccontrol
    ];

    finit.services.ddccontrol = {
      description = "control monitor parameters, like brightness, contrast, and other...";
      command = "${pkgs.ddccontrol}/libexec/ddccontrol/ddccontrol_service";
			conditions = [ "service/dbus/ready" ];
    };
  };
}
