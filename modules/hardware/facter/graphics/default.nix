{ lib, config, ... }:
let
  cfg = config.hardware.facter.detected.graphics;

  facterLib = import ../lib.nix lib;
in
{
  options.hardware.facter.detected = {
    graphics.enable = lib.mkOption {
      type = lib.types.bool;
      default = builtins.length (config.hardware.facter.report.hardware.monitor or [ ]) > 0;
      defaultText = "hardware dependent";
      description = "Whether to enable the Facter Graphics module.";
    };

    boot.graphics.kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # We currently don't auto import nouveau, in case the user might want to use the proprietary nvidia driver,
      # We might want to change this in future, if we have a better idea, how to handle this.
      default = lib.remove "nouveau" (
        lib.uniqueStrings (
          facterLib.collectDrivers (config.hardware.facter.report.hardware.graphics_card or [ ])
        )
      );
      defaultText = "hardware dependent";
      description = "List of kernel modules to load at boot for the graphics card.";
    };
  };

  config = lib.mkIf (config.hardware.facter.enable && cfg.enable) {
    boot.initrd.kernelModules = config.hardware.facter.detected.boot.graphics.kernelModules;

    # Facter has this depend on stateVersion
    hardware.graphics.enable = lib.mkDefault true;
  };
}
