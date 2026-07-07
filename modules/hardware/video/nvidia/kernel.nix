{ config, lib, pkgs, ... }:
let
  common = import ./common.nix { inherit config lib pkgs; };
  inherit (common) cfg ibtSupport;
in
{
  config = lib.mkIf cfg.enable {
    environment.etc."modprobe.d/nvidia-uvm.conf".text = ''
      softdep nvidia post: nvidia_uvm
    '';

    environment.etc."modprobe.d/nvidia-blacklists.conf".text = ''
      blacklist nouveau
      options nouveau modeset=0
      blacklist nvidiafb
      blacklist nova_core
    '';

    boot = {
      extraModulePackages =
        if cfg.kernelModule == "open" then [ cfg.package.open ] else [ cfg.package.mod ];

      kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_drm"
      ]
      ++ lib.optionals (cfg.kernelModule == "open") [ "nvidia_uvm" ];

      kernelParams =
        lib.optionals (cfg.kernelModule == "open") [ "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1" ]
        ++ lib.optionals (cfg.powerManagement.enable && cfg.powerManagement.kernelSuspendNotifier) [
          "nvidia.NVreg_UseKernelSuspendNotifiers=1"
        ]
        ++ lib.optionals cfg.powerManagement.enable [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ]
        ++ lib.optionals cfg.powerManagement.finegrained [ "nvidia.NVreg_DynamicPowerManagement=0x02" ]
        ++ lib.optionals (config.boot.kernelPackages.kernel.kernelAtLeast "6.2" && !ibtSupport) [
          "ibt=off"
        ]
        ++ lib.optionals cfg.modesetting.enable [ "nvidia-drm.modeset=1" ]
        ++ lib.optionals (cfg.modesetting.enable && lib.versionAtLeast cfg.package.version "545") [
          "nvidia-drm.fbdev=1"
        ];
    };

    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/60-nvidia.rules" ''
        KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c 195 255'"
        KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d \  -f 4); do mknod -m 666 /dev/nvidia$${i} c 195 $${i}; done'"
        KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c 195 254'"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"

        KERNEL=="card*", SUBSYSTEM=="drm", GROUP="video", MODE="0660"
        KERNEL=="renderD*", SUBSYSTEM=="drm", GROUP="render", MODE="0660"
      '')
    ]
    ++ lib.optionals cfg.powerManagement.finegrained [
      (pkgs.writeTextDir "lib/udev/rules.d/80-nvidia-pm.rules" ''
        ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="on"
      '')
    ];
  };
}