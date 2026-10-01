{ lib, config, ... }:
let
  facterLib = import ./lib.nix lib;

  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;
  hasAmdCpu = facterLib.hasAmdCpu report;

  kver = config.boot.kernelPackages.kernel.version;

  kernelParams =
    if lib.versionAtLeast kver "6.3" then
      [ "amd_pstate=active" ]
    else if lib.versionAtLeast kver "6.1" then
      [ "amd_pstate=passive" ]
    else if lib.versionAtLeast kver "5.17" then
      [ "initcall_blacklist=acpi_cpufreq_init" ]
    else
      [ ];

  kernelModules =
    if lib.versionAtLeast kver "5.17" && lib.versionOlder kver "6.1" then [ "amd-pstate" ] else [ ];
in
lib.mkIf (config.hardware.facter.enable && isBaremetal && hasAmdCpu) {
  boot = {
    inherit kernelParams kernelModules;
  };
}
