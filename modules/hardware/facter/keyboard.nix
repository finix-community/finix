{ lib, config, ... }:
let
  facterLib = import ./lib.nix lib;

  inherit (config.hardware.facter) report;
in
{
  options.hardware.facter.detected.boot.keyboard.kernelModules = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = lib.uniqueStrings (facterLib.collectDrivers (report.hardware.usb_controller or [ ]));
    defaultText = "hardware dependent";
    description = "List of kernel modules to include in the initrd to support the keyboard.";
    example = [ "usbhid" ];
  };

  config = lib.mkIf config.hardware.facter.enable {
    boot.initrd.availableKernelModules = config.hardware.facter.detected.boot.keyboard.kernelModules;
  };
}
