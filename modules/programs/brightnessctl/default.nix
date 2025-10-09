{ config, pkgs, lib, ... }:
let
  cfg = config.programs.brightnessctl;

  package = pkgs.callPackage ./package.nix { };
in
{
  options.programs.brightnessctl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = package.override {
        logindSupport = config.services.elogind.enable;
        udevSupport = config.services.udev.enable;
      };
      defaultText = lib.literalExpression ''
        pkgs.brightnessctl.override {
          logindSupport = config.services.elogind.enable;
          udevSupport = config.services.udev.enable;
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.udev.packages = [ cfg.package ];
    services.mdevd.hotplugRules = ''
      -SUBSYSTEM=backlight;.* root:root 0600 @chgrp video /sys/class/backlight/$MDEV/brightness
      SUBSYSTEM=backlight;.* root:root 0600 @chmod g+w /sys/class/backlight/$MDEV/brightness

      -SUBSYSTEM=leds;.* root:root 0600 @chgrp input /sys/class/leds/$MDEV/brightness
      SUBSYSTEM=leds;.* root:root 0600 @chmod g+w /sys/class/leds/$MDEV/brightness
    '';
  };
}
