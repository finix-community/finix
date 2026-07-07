{ config, lib, ... }:
let
  common = import ./common.nix { inherit config lib; pkgs = null; };
  inherit (common) cfg primeEnabled gpuIDs;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.powerManagement.enable -> lib.versionAtLeast cfg.package.version "430.09";
        message = "Required files for driver based power management only exist on versions >= 430.09.";
      }
      {
        assertion =
          (cfg.powerManagement.enable && !cfg.powerManagement.kernelSuspendNotifier)
          -> config.providers.resumeAndSuspend.backend != "none";
        message = "Power management without `kernelSuspendNotifier` requires a sleep backend. Enable programs.zzz (programs.zzz.enable = true).";
      }
      {
        assertion = cfg.gsp.enable -> (cfg.package ? firmware);
        message = "This version of NVIDIA driver does not provide a GSP firmware.";
      }
      {
        assertion = cfg.kernelModule == "open" -> (cfg.package ? open);
        message = "This version of NVIDIA driver does not provide a corresponding opensource kernel driver.";
      }
      {
        assertion = cfg.kernelModule == "open" -> cfg.gsp.enable;
        message = "The GSP cannot be disabled when using the opensource kernel driver.";
      }
      {
        assertion =
          cfg.powerManagement.kernelSuspendNotifier
          -> (cfg.kernelModule == "open" && lib.versionAtLeast cfg.package.version "595");
        message = "NVIDIA driver support for kernel suspend notifiers requires NVIDIA driver version 595 or newer, and the open source kernel modules.";
      }
      {
        assertion = !(cfg.prime.offload.enable && cfg.prime.sync.enable);
        message = "prime.offload.enable and prime.sync.enable are mutually exclusive.";
      }
      {
        assertion = cfg.prime.offload.enableOffloadCmd -> cfg.prime.offload.enable;
        message = "prime.offload.enableOffloadCmd requires prime.offload.enable = true.";
      }
      {
        assertion = cfg.powerManagement.finegrained -> cfg.prime.offload.enable;
        message = "powerManagement.finegrained requires prime.offload.enable = true.";
      }
      {
        assertion = primeEnabled -> (cfg.prime.nvidiaBusId != null && lib.length gpuIDs >= 2);
        message = "PRIME requires prime.nvidiaBusId and at least one of prime.intelBusId / prime.amdgpuBusId to be set.";
      }
    ];
  };
}