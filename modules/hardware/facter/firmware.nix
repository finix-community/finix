{
  lib,
  config,
  pkgs,
  ...
}:
let
  facterLib = import ./lib.nix lib;

  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;
  hasAmdCpu = facterLib.hasAmdCpu report;
  hasIntelCpu = facterLib.hasIntelCpu report;
in
lib.mkIf (config.hardware.facter.enable && isBaremetal) {
  hardware.firmware = [
    pkgs.linux-firmware
  ];

  hardware.cpu.amd.updateMicrocode = lib.mkIf hasAmdCpu (lib.mkDefault true);
  hardware.cpu.intel.updateMicrocode = lib.mkIf hasIntelCpu (lib.mkDefault true);
}
