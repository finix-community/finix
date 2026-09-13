{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (import ./common.nix { inherit lib config; }) cfg ibtSupport;
in
{
  config = lib.mkIf cfg.enable {
    environment.etc = {
      # Don't add `nvidia-uvm` to `kernelModules`, because we want
      # `nvidia-uvm` be loaded only after the GPU device is available, i.e. after `udev` rules
      # for `nvidia` kernel module are applied.
      # This matters on Azure GPU instances: https://github.com/NixOS/nixpkgs/pull/267335
      #
      # Instead, we use `softdep` to lazily load `nvidia-uvm` kernel module
      # after `nvidia` kernel module is loaded and `udev` rules are applied.
      "modprobe.d/nvidia-uvm.conf".text = ''
        softdep nvidia post: nvidia_uvm
      '';

      "modprobe.d/nvidia-blacklists.conf".text = ''
        blacklist nouveau
        options nouveau modeset=0
        blacklist nvidiafb
        blacklist nova_core
      '';
    };

    boot = {
      extraModulePackages =
        if cfg.kernelModule == "open" then [ cfg.package.open ] else [ cfg.package.mod ];

      # nvidia-uvm is required by CUDA applications.
      # Exception is the open-source kernel module failing to load nvidia-uvm using softdep
      # for unknown reasons.
      # It affects CUDA: https://github.com/NixOS/nixpkgs/issues/334180
      # Previously nvidia-uvm was explicitly loaded only when xorg was enabled:
      # https://github.com/NixOS/nixpkgs/pull/334340/commits/4548c392862115359e50860bcf658cfa8715bde9
      # We are now loading the module eagerly for all users of the open driver (including headless).
      kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_drm"
      ]
      ++ lib.optionals (cfg.kernelModule == "open") [ "nvidia_uvm" ];

      kernelParams =
        lib.optionals (cfg.kernelModule == "open") [ "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1" ]
        ++ lib.optionals (cfg.power.suspend.enable && cfg.power.suspend.notifier == "kernel") [
          "nvidia.NVreg_UseKernelSuspendNotifiers=1"
        ]
        ++ lib.optionals cfg.power.suspend.enable [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ]
        ++ lib.optionals cfg.power.runtime.enable [ "nvidia.NVreg_DynamicPowerManagement=0x02" ]
        ++ lib.optionals (config.boot.kernelPackages.kernel.kernelAtLeast "6.2" && !ibtSupport) [
          "ibt=off"
        ]
        ++ lib.optionals cfg.modesetting.enable [ "nvidia-drm.modeset=1" ]
        ++ lib.optionals (cfg.modesetting.enable && lib.versionAtLeast cfg.package.version "545") [
          "nvidia-drm.fbdev=1"
        ];
    };

    services.mdevd.hotplugRules =
      let
        # mdevd only sees one uevent for the "nvidia" frontend device, but the actual character devices
        # it has to be mknod'd by hand (nvidiactl + one nvidia<N> per card), same as the udev rule below does
        nvidiaMdevScript = pkgs.writeScript "mdevd-nvidia.sh" ''
          #!/bin/sh
          case "$MDEV" in
            nvidia)
              mknod -m 666 /dev/nvidiactl c 195 255
              for i in $(cat /proc/driver/nvidia/gpus/*/information 2>/dev/null | grep Minor | cut -d ' ' -f 4); do
                mknod -m 666 "/dev/nvidia$i" c 195 "$i"
              done
              ;;
            nvidia_modeset)
              mknod -m 666 /dev/nvidia-modeset c 195 254
              ;;
            nvidia_uvm)
              uvm_major=$(grep nvidia-uvm /proc/devices | cut -d ' ' -f 1)
              mknod -m 666 /dev/nvidia-uvm c "$uvm_major" 0
              mknod -m 666 /dev/nvidia-uvm-tools c "$uvm_major" 1
              ;;
          esac
        '';
      in
      # "!" stops mdevd from creating its own default node for these three
      ''
        nvidia          0:0 666 ! @${nvidiaMdevScript}
        nvidia_modeset  0:0 666 ! @${nvidiaMdevScript}
        nvidia_uvm      0:0 666 ! @${nvidiaMdevScript}
      '';

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
    ];
  };
}
