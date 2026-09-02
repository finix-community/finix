{ config, lib, ... }:
let
  inherit (import ./common.nix { inherit lib config; }) cfg;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.power.suspend.enable -> lib.versionAtLeast cfg.package.version "430.09";
        message = "Required files for driver based power management only exist on versions >= 430.09.";
      }

      {
        assertion =
          (cfg.power.suspend.enable && cfg.power.suspend.notifier == "userspace")
          -> config.providers.resumeAndSuspend.backend != "none";
        message = "`power.suspend.notifier = \"userspace\"` requires a sleep backend. Enable programs.zzz (programs.zzz.enable = true).";
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
          cfg.power.suspend.notifier == "kernel"
          -> (cfg.kernelModule == "open" && lib.versionAtLeast cfg.package.version "595");
        message = "`power.suspend.notifier = \"kernel\"` requires NVIDIA driver version 595 or newer, and the open source kernel modules.";
      }

      {
        assertion = cfg.power.runtime.enable -> cfg.prime.offload.enable;
        message = "`power.runtime.enable` requires `prime.offload.enable`.";
      }
    ];
  };
}
