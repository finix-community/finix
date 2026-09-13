{ config, lib, ... }:
let
  cfg = config.hardware.nvidia;
in
{
  options.hardware.nvidia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable NVIDIA driver support.";
    };

    power.suspend.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to preserve video memory allocations across system suspend and
        hibernate. For more information, see the NVIDIA docs, on Chapter 21.
        Configuring Power Management Support.
      '';
    };

    power.suspend.notifier = lib.mkOption {
      type = lib.types.enum [
        "kernel"
        "userspace"
      ];
      default =
        if cfg.kernelModule == "open" && lib.versionAtLeast cfg.package.version "595" then
          "kernel"
        else
          "userspace";
      defaultText = lib.literalExpression ''
        if config.hardware.nvidia.kernelModule == "open" && lib.versionAtLeast config.hardware.nvidia.package.version "595" then "kernel" else "userspace"
      '';
      description = ''
        How the NVIDIA driver is notified of system suspend and resume events
        when `power.suspend.enable` is set:

        - `kernel`: the kernel notifies the driver directly. Requires NVIDIA
          driver version 595 or newer, and the open source kernel modules.
        - `userspace`: relies on nvidia-sleep.sh being run by the sleep backend
          (requires a sleep backend, e.g. programs.zzz).
      '';
    };

    power.runtime.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable fine-grained dynamic power management. When enabled,
        the NVIDIA GPU is powered down when not in use. Only works in PRIME
        offload mode (prime.offload.enable = true). Requires kernel >= 5.5 and
        a Turing or newer GPU. Sets NVreg_DynamicPowerManagement=0x02.
      '';
    };

    modesetting.enable = lib.mkOption {
      type = lib.types.bool;
      default = lib.versionAtLeast cfg.package.version "535";
      defaultText = lib.literalExpression "lib.versionAtLeast cfg.package.version \"535\"";
      description = ''
        Whether to enable kernel modesetting when using the NVIDIA proprietary
        driver.

        Enabling this can fix screen tearing. This is not enabled by default
        because it is not officially supported by NVIDIA and would not work
        with SLI.

        Enabling this and using version 545 or newer of the proprietary NVIDIA
        driver causes it to provide its own framebuffer device, which can cause
        Wayland compositors to work when they otherwise wouldn't.
      '';
    };

    package = lib.mkOption {
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = lib.literalExpression ''
        config.boot.kernelPackages.nvidiaPackages.stable
      '';
      example = "config.boot.kernelPackages.nvidiaPackages.legacy_470";
      description = ''
        The NVIDIA driver package to use.
      '';
    };

    kernelModule = lib.mkOption {
      type = lib.types.enum [
        "open"
        "closed"
      ];
      default = "closed";
      example = "open";
      description = ''
        Which NVIDIA kernel module to use: the "open" source GPU kernel
        modules (recommended on Turing and later GPUs, required on the newest
        GPUs) or the "closed" proprietary ones.
      '';
    };

    gsp.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.kernelModule == "open" || lib.versionAtLeast cfg.package.version "555";
      defaultText = lib.literalExpression ''
        config.hardware.nvidia.kernelModule == "open" || lib.versionAtLeast config.hardware.nvidia.package.version "555"
      '';
      description = "Whether to enable the GPU System Processor (GSP) on the video card.";
    };

    videoAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable video acceleration (VA-API).";
    };
  };
}
