{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.hardware.nvidia;

  ibtSupport = (cfg.kernelModule == "open") || (cfg.package.ibtSupport or false);

  icd = [
    "egl-wayland"
  ]
  # GBM support was added in 495.
  ++ lib.optionals (lib.versionAtLeast cfg.package.version "495") [
    "egl-gbm"
  ]
  # ICDs below use a new driver interface, which is added in the 560 series drivers.
  ++ lib.optionals (lib.versionAtLeast cfg.package.version "560") [
    "egl-wayland2"
    "egl-x11"
  ];

  combineIcdPkgs =
    pkgs':
    pkgs'.symlinkJoin {
      name = "nvidia-egl-external-platforms${lib.optionalString pkgs'.stdenv.is32bit "-x32"}";
      paths = lib.attrVals icd pkgs';
      # Remediate reversed priorities in pre-595 drivers,
      # https://github.com/NixOS/nixpkgs/pull/497342#issuecomment-4034876793
      postBuild = lib.optionalString (lib.versionOlder cfg.package.version "595") ''
        pushd $out/share/egl/egl_external_platform.d
        for f in [0-9][0-9]_*; do
          num=''${f:0:2}
          rest=''${f:2}
          new=$(printf "%02d" $((99 - 10#$num)))
          mv -- "$f" "tmp-$new$rest"
        done
        for f in tmp-*; do
          mv -- "$f" "''${f#tmp-}"
        done
        popd
      '';
    };

  # PCI bus ID validator: accepts "PCI:x:y:z" format
  busIdType = lib.types.strMatching "PCI:[0-9]+:[0-9]+:[0-9]+" // {
    description = "PCI bus ID in format PCI:x:y:z (e.g. PCI:0:2:0)";
  };

  # nvidia-offload wrapper script for PRIME offload mode
  offloadScript = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';

  primeEnabled = cfg.prime.offload.enable || cfg.prime.sync.enable;
  gpuIDs = lib.filter (x: x != null) [
    cfg.prime.intelBusId
    cfg.prime.nvidiaBusId
    cfg.prime.amdgpuBusId
  ];
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

  config = lib.mkMerge [
    (lib.mkIf (cfg.open != null) {
      hardware.nvidia.kernelModule = if cfg.open then "open" else "closed";
    })

    (lib.mkIf cfg.enable {
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
          assertion =
            primeEnabled -> (cfg.prime.nvidiaBusId != null && lib.length gpuIDs >= 2);
          message = "PRIME requires prime.nvidiaBusId and at least one of prime.intelBusId / prime.amdgpuBusId to be set.";
        }
      ];

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

        "nvidia/nvidia-application-profiles-rc" = lib.mkIf cfg.package.useProfiles {
          source = "${cfg.package.bin}/share/nvidia/nvidia-application-profiles-rc";
        };

      # 'cfg.package' installs it's files to /run/opengl-driver/...
        "egl/egl_external_platform.d".source = "/run/opengl-driver/share/egl/egl_external_platform.d/";
      };

      boot = {
        extraModulePackages =
          if cfg.kernelModule == "open" then [ cfg.package.open ] else [ cfg.package.bin ];

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
      # Fine-grained power management: enable runtime PM for the NVIDIA PCI device
      ++ lib.optionals cfg.powerManagement.finegrained [
        (pkgs.writeTextDir "lib/udev/rules.d/80-nvidia-pm.rules" ''
          # Enable runtime PM for NVIDIA VGA/3D controller
          ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
          ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
          # Enable runtime PM for NVIDIA Audio device
          ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
          # Disable runtime PM when driver unbinds
          ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
          ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
          ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="on"
        '')
      ];

      hardware.graphics.extraPackages = [
        cfg.package.out
        (combineIcdPkgs pkgs)
      ]
      ++ lib.optionals cfg.videoAcceleration [ pkgs.nvidia-vaapi-driver ];

      hardware.graphics.extraPackages32 = [
        cfg.package.lib32
        (combineIcdPkgs pkgs.pkgsi686Linux)
      ];

      hardware.firmware = lib.optional cfg.gsp.enable cfg.package.firmware;

      providers.resumeAndSuspend.hooks =
        lib.optionalAttrs (cfg.powerManagement.enable && !cfg.powerManagement.kernelSuspendNotifier)
          {
            nvidia-suspend = {
              event = "suspend";
              action = "PATH=${pkgs.kbd}/bin:$PATH ${cfg.package.out}/bin/nvidia-sleep.sh 'suspend'";
              priority = 100;
            };
            nvidia-hibernate = {
              event = "hibernate";
              action = "${cfg.package.out}/bin/nvidia-sleep.sh 'hibernate'";
              priority = 100;
            };
            nvidia-resume = {
              event = "resume";
              action = "${cfg.package.out}/bin/nvidia-sleep.sh 'resume'";
              priority = 900;
            };
          };

      environment.systemPackages =
        [ cfg.package.bin ]
        ++ lib.optionals cfg.nvidiaSettings [ cfg.package.bin ] # nvidia-settings is bundled in .bin
        ++ lib.optionals cfg.prime.offload.enableOffloadCmd [ offloadScript ];
    })

    (lib.mkIf (cfg.enable && primeEnabled) {
      environment.etc."X11/xorg.conf.d/10-nvidia-prime.conf".text =
        let
          mkBusIdSection = busId: driver: extra: ''
            Section "Device"
              Identifier "${driver}"
              Driver "${driver}"
              BusID "${busId}"
              ${extra}
            EndSection
          '';

          intelSection = lib.optionalString (cfg.prime.intelBusId != null) (
            mkBusIdSection cfg.prime.intelBusId "intel" ''
              Option "DRI" "3"
            ''
          );

          amdSection = lib.optionalString (cfg.prime.amdgpuBusId != null) (
            mkBusIdSection cfg.prime.amdgpuBusId "amdgpu" ""
          );

          nvidiaSection = lib.optionalString (cfg.prime.nvidiaBusId != null) (
            mkBusIdSection cfg.prime.nvidiaBusId "nvidia" (
              lib.optionalString cfg.prime.offload.enable ''
                Option "AllowEmptyInitialConfiguration"
              ''
            )
          );

          igpuId =
            if cfg.prime.intelBusId != null then "intel"
            else if cfg.prime.amdgpuBusId != null then "amdgpu"
            else null;

          syncLayout = lib.optionalString (cfg.prime.sync.enable && igpuId != null) ''
            Section "ServerLayout"
              Identifier "layout"
              Screen "nvidia"
              Inactive "${igpuId}"
              Option "AllowNVIDIAGPUScreens"
            EndSection
          '';
        in
        ''
          ${intelSection}
          ${amdSection}
          ${nvidiaSection}
          ${syncLayout}
        '';
    })
  ];
}
