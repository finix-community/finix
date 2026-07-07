{ lib, config, ... }:
let
  cfg = config.hardware.nvidia;

  busIdType = lib.types.strMatching "PCI:[0-9]+:[0-9]+:[0-9]+" // {
    description = "PCI bus ID in format PCI:x:y:z (e.g. PCI:0:2:0)";
  };
in
{
  options.hardware.nvidia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable NVIDIA driver support.";
    };

    open = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Compatibility alias for kernelModule. Set to true to use the open
        source kernel module (equivalent to kernelModule = "open"), false for
        the closed proprietary one. If set, it overrides kernelModule.
        Prefer setting kernelModule directly in new configs.
      '';
    };

    nvidiaSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to add nvidia-settings to systemPackages. The GUI app for
        configuring the NVIDIA driver at runtime.
      '';
    };

    powerManagement.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable experimental power management through systemd. For
        more information, see the NVIDIA docs, on Chapter 21. Configuring
        Power Management Support.
      '';
    };

    powerManagement.finegrained = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable fine-grained dynamic power management. When enabled,
        the NVIDIA GPU is powered down when not in use. Only works in PRIME
        offload mode (prime.offload.enable = true). Requires kernel >= 5.5
        and a Turing or newer GPU. Sets NVreg_DynamicPowerManagement=0x02.
      '';
    };

    powerManagement.kernelSuspendNotifier = lib.mkOption {
      type = lib.types.bool;
      default = cfg.kernelModule == "open" && lib.versionAtLeast cfg.package.version "595";
      defaultText = lib.literalExpression ''
        config.hardware.nvidia.kernelModule == "open" && lib.versionAtLeast config.hardware.nvidia.package.version "595"
      '';
      description = ''
        Whether to enable NVIDIA driver support for kernel suspend notifiers,
        which allows the driver to be notified of suspend and resume events by
        the kernel, rather than relying on systemd services. Requires NVIDIA
        driver version 595 or newer, and the open source kernel modules.
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

    prime.offload.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable PRIME offload mode. The iGPU handles display output
        and general rendering; the NVIDIA GPU is used only when explicitly
        requested (via the nvidia-offload wrapper or DRI_PRIME env var).
        Cannot be used together with prime.sync.enable.
      '';
    };

    prime.offload.enableOffloadCmd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to add an `nvidia-offload` wrapper script to systemPackages.
        Run `nvidia-offload <program>` to launch a program on the NVIDIA GPU.
        Requires prime.offload.enable = true.
      '';
    };

    prime.sync.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable PRIME sync mode. Both GPUs are active simultaneously;
        the NVIDIA GPU renders and the iGPU handles display. Eliminates tearing
        but uses more power than offload mode. Cannot be used with
        prime.offload.enable.
      '';
    };

    prime.intelBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:0:2:0";
      description = ''
        The PCI bus ID of the Intel iGPU. Find it with:
          lspci | grep -i intel | grep -i vga
        then convert the hex address (e.g. 00:02.0) to PCI:0:2:0.
      '';
    };

    prime.nvidiaBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:1:0:0";
      description = ''
        The PCI bus ID of the NVIDIA GPU. Find it with:
          lspci | grep -i nvidia
        then convert the hex address (e.g. 01:00.0) to PCI:1:0:0.
      '';
    };

    prime.amdgpuBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:4:0:0";
      description = ''
        The PCI bus ID of the AMD iGPU (for AMD+NVIDIA Optimus laptops).
        Find it with: lspci | grep -i amd | grep -i vga
      '';
    };
  };
}