{ config, pkgs, lib, ... }:
let
  cfg = config.services.ddccontrol;
in
{
  options.services.ddccontrol = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ddccontrol](${pkgs.ddccontrol.meta.homepage}) as a system service.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.i2c.enable = true;

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
