{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.hardware.nvidia;

  useOpenModules = cfg.open == true;

  primeCfg = cfg.prime;
  syncCfg = primeCfg.sync;
  offloadCfg = primeCfg.offload;
  reverseSyncCfg = primeCfg.reverseSync;
  primeEnabled = syncCfg.enable || reverseSyncCfg.enable || offloadCfg.enable;

  busIDType = lib.types.strMatching "([[:print:]]+:[0-9]{1,3}(@[0-9]{1,10})?:[0-9]{1,2}:[0-9])?";
  ibtSupport = useOpenModules || (cfg.package.ibtSupport or false);

  useModeset = offloadCfg.enable || cfg.modesetting.enable;

  # EGL external-platform ICDs that the NVIDIA driver advertises to compositors.
  icd = [
    "egl-wayland"
  ]
  # GBM support was added in 495.
  ++ lib.optionals (lib.versionAtLeast cfg.package.version "495") [
    "egl-gbm"
  ]
  # ICDs below use a new driver interface, added in the 560 series drivers.
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
in
{
  options = {
    hardware.nvidia = {
      enable = lib.mkEnableOption ''
        NVIDIA driver support
      '';

      powerManagement.enable = lib.mkEnableOption ''
        experimental power management through systemd. For more information, see
        the NVIDIA docs, on Chapter 21. Configuring Power Management Support
      '';

      powerManagement.finegrained = lib.mkEnableOption ''
        experimental power management of PRIME offload. For more information, see
        the NVIDIA docs, on Chapter 22. PCI-Express Runtime D3 (RTD3) Power Management
      '';

      powerManagement.kernelSuspendNotifier =
        lib.mkEnableOption ''
          NVIDIA driver support for kernel suspend notifiers, which allows the driver
          to be notified of suspend and resume events by the kernel, rather than
          relying on systemd services.
          Requires NVIDIA driver version 595 or newer, and the open source kernel modules.
        ''
        // {
          default = useOpenModules && lib.versionAtLeast cfg.package.version "595";
          defaultText = lib.literalExpression ''
            config.hardware.nvidia.open == true && lib.versionAtLeast config.hardware.nvidia.package.version "595"
          '';
        };

      modesetting.enable =
        lib.mkEnableOption ''
          kernel modesetting when using the NVIDIA proprietary driver.

          Enabling this fixes screen tearing when using Optimus via PRIME (see
          {option}`hardware.nvidia.prime.sync.enable`. This is not enabled
          by default because it is not officially supported by NVIDIA and would not
          work with SLI.

          Enabling this and using version 545 or newer of the proprietary NVIDIA
          driver causes it to provide its own framebuffer device, which can cause
          Wayland compositors to work when they otherwise wouldn't.
        ''
        // {
          default = lib.versionAtLeast cfg.package.version "535";
          defaultText = lib.literalExpression "lib.versionAtLeast cfg.package.version \"535\"";
        };

      prime.nvidiaBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:1@0:0:0";
        description = ''
          Bus ID of the NVIDIA GPU. You can find it using lspci; for example if lspci
          shows the NVIDIA GPU at "0001:02:03.4", set this option to "PCI:2@1:3:4".

          lspci might omit the PCI domain (0001 in above example) if it is zero.
          In which case, use "@0" instead.

          Please be aware that this option takes decimal address while lspci reports
          hexadecimal address. So for device at domain "10000", use "@65536".
        '';
      };

      prime.intelBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:0@0:2:0";
        description = ''
          Bus ID of the Intel GPU. You can find it using lspci; for example if lspci
          shows the Intel GPU at "0001:02:03.4", set this option to "PCI:2@1:3:4".

          lspci might omit the PCI domain (0001 in above example) if it is zero.
          In which case, use "@0" instead.

          Please be aware that this option takes decimal address while lspci reports
          hexadecimal address. So for device at domain "10000", use "@65536".
        '';
      };

      prime.amdgpuBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:4@0:0:0";
        description = ''
          Bus ID of the AMD APU. You can find it using lspci; for example if lspci
          shows the AMD APU at "0001:02:03.4", set this option to "PCI:2@1:3:4".

          lspci might omit the PCI domain (0001 in above example) if it is zero.
          In which case, use "@0" instead.

          Please be aware that this option takes decimal address while lspci reports
          hexadecimal address. So for device at domain "10000", use "@65536".
        '';
      };

      prime.sync.enable = lib.mkEnableOption ''
        NVIDIA Optimus support using the NVIDIA proprietary driver via PRIME.
        If enabled, the NVIDIA GPU will be always on and used for all rendering,
        while enabling output to displays attached only to the integrated Intel/AMD
        GPU without a multiplexer.

        Note that this option only has any effect if the "nvidia" driver is specified
        in {option}`services.xserver.videoDrivers`, and it should preferably
        be the only driver there.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified ({option}`hardware.nvidia.prime.nvidiaBusId` and
        {option}`hardware.nvidia.prime.intelBusId` or
        {option}`hardware.nvidia.prime.amdgpuBusId`).

        If you enable this, you may want to also enable kernel modesetting for the
        NVIDIA driver ({option}`hardware.nvidia.modesetting.enable`) in order
        to prevent tearing.

        Note that this configuration will only be successful when a display manager
        for which the {option}`services.xserver.displayManager.setupCommands`
        option is supported is used
      '';

      prime.allowExternalGpu = lib.mkEnableOption ''
        configuring X to allow external NVIDIA GPUs when using Prime [Reverse] sync optimus
      '';

      prime.offload.enable = lib.mkEnableOption ''
        render offload support using the NVIDIA proprietary driver via PRIME.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified ({option}`hardware.nvidia.prime.nvidiaBusId` and
        {option}`hardware.nvidia.prime.intelBusId` or
        {option}`hardware.nvidia.prime.amdgpuBusId`)
      '';

      prime.offload.enableOffloadCmd = lib.mkEnableOption ''
        adding a `nvidia-offload` convenience script to {option}`environment.systemPackages`
        for offloading programs to an nvidia device. To work, you must also enable
        {option}`hardware.nvidia.prime.offload.enable` or {option}`hardware.nvidia.prime.reverseSync.enable`.

        Example usage: `nvidia-offload sauerbraten_client`

        This script can be renamed with {option}`hardware.nvidia.prime.offload.enableOffloadCmd`.
      '';
      prime.offload.offloadCmdMainProgram = lib.mkOption {
        type = lib.types.str;
        description = ''
          Specifies the CLI name of the {option}`hardware.nvidia.prime.offload.enableOffloadCmd`
          convenience script for offloading programs to an nvidia device.
        '';
        default = "nvidia-offload";
        example = "prime-run";
      };

      prime.reverseSync.enable = lib.mkEnableOption ''
        NVIDIA Optimus support using the NVIDIA proprietary driver via reverse
        PRIME. If enabled, the Intel/AMD GPU will be used for all rendering, while
        enabling output to displays attached only to the NVIDIA GPU without a
        multiplexer.

        Warning: This feature is relatively new, depending on your system this might
        work poorly. AMD support, especially so.
        See: <https://forums.developer.nvidia.com/t/the-all-new-outputsink-feature-aka-reverse-prime/129828>

        Note that this option only has any effect if the "nvidia" driver is specified
        in {option}`services.xserver.videoDrivers`, and it should preferably
        be the only driver there.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified ({option}`hardware.nvidia.prime.nvidiaBusId` and
        {option}`hardware.nvidia.prime.intelBusId` or
        {option}`hardware.nvidia.prime.amdgpuBusId`).

        If you enable this, you may want to also enable kernel modesetting for the
        NVIDIA driver ({option}`hardware.nvidia.modesetting.enable`) in order
        to prevent tearing.

        Note that this configuration will only be successful when a display manager
        for which the {option}`services.xserver.displayManager.setupCommands`
        option is supported is used
      '';

      prime.reverseSync.setupCommands.enable =
        (lib.mkEnableOption ''
          configure the display manager to be able to use the outputs
          attached to the NVIDIA GPU.
          Disable in order to configure the NVIDIA GPU outputs manually using xrandr.
          Note that this configuration will only be successful when a display manager
          for which the {option}`services.xserver.displayManager.setupCommands`
          option is supported is used
        '')
        // {
          default = true;
        };

      forceFullCompositionPipeline = lib.mkEnableOption ''
        forcefully the full composition pipeline.
        This sometimes fixes screen tearing issues.
        This has been reported to reduce the performance of some OpenGL applications and may produce issues in WebGL.
        It also drastically increases the time the driver needs to clock down after load
      '';

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

      open = lib.mkOption {
        example = true;
        description = "Whether to enable the open source NVIDIA kernel module.";
        type = lib.types.nullOr lib.types.bool;
        default = if lib.versionOlder cfg.package.version "560" then false else null;
        defaultText = lib.literalExpression ''
          if lib.versionOlder config.hardware.nvidia.package.version "560" then false else null
        '';
      };

      gsp.enable =
        lib.mkEnableOption ''
          the GPU System Processor (GSP) on the video card
        ''
        // {
          default = useOpenModules || lib.versionAtLeast cfg.package.version "555";
          defaultText = lib.literalExpression ''
            config.hardware.nvidia.open == true || lib.versionAtLeast config.hardware.nvidia.package.version "555"
          '';
        };

      videoAcceleration =
        (lib.mkEnableOption ''
          Whether video acceleration (VA-API) should be enabled.
        '')
        // {
          default = true;
        };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
          {
            assertion = cfg.open != null;
            message = ''
              You must configure `hardware.nvidia.open` on NVIDIA driver versions >= 560.
              It is suggested to use the open source kernel modules on Turing or later GPUs (RTX series, GTX 16xx), and the closed source modules otherwise.
            '';
          }

          {
            assertion = primeEnabled -> primeCfg.intelBusId == "" || primeCfg.amdgpuBusId == "";
            message = "You cannot configure both an Intel iGPU and an AMD APU. Pick the one corresponding to your processor.";
          }

          {
            assertion = offloadCfg.enableOffloadCmd -> offloadCfg.enable || reverseSyncCfg.enable;
            message = "Offload command requires offloading or reverse prime sync to be enabled.";
          }

          {
            assertion =
              primeEnabled -> primeCfg.nvidiaBusId != "" && (primeCfg.intelBusId != "" || primeCfg.amdgpuBusId != "");
            message = "When NVIDIA PRIME is enabled, the GPU bus IDs must be configured.";
          }

          {
            assertion = offloadCfg.enable -> lib.versionAtLeast cfg.package.version "435.21";
            message = "NVIDIA PRIME render offload is currently only supported on versions >= 435.21.";
          }

          {
            assertion =
              (reverseSyncCfg.enable && primeCfg.amdgpuBusId != "") -> lib.versionAtLeast cfg.package.version "470.0";
            message = "NVIDIA PRIME render offload for AMD APUs is currently only supported on versions >= 470 beta.";
          }

          {
            assertion = !(syncCfg.enable && offloadCfg.enable);
            message = "PRIME Sync and Offload cannot be both enabled";
          }

          {
            assertion = !(syncCfg.enable && reverseSyncCfg.enable);
            message = "PRIME Sync and PRIME Reverse Sync cannot be both enabled";
          }

          {
            assertion = !(syncCfg.enable && cfg.powerManagement.finegrained);
            message = "Sync precludes powering down the NVIDIA GPU.";
          }

          {
            assertion = cfg.powerManagement.finegrained -> offloadCfg.enable;
            message = "Fine-grained power management requires offload to be enabled.";
          }

          {
            assertion = cfg.powerManagement.enable -> lib.versionAtLeast cfg.package.version "430.09";
            message = "Required files for driver based power management only exist on versions >= 430.09.";
          }

          {
            assertion = (cfg.powerManagement.enable && !cfg.powerManagement.kernelSuspendNotifier) -> config.providers.resumeAndSuspend.backend != "none";
            message = "Power management without `kernelSuspendNotifier` requires a sleep backend. Enable programs.zzz (programs.zzz.enable = true).";
          }

          {
            assertion = cfg.gsp.enable -> (cfg.package ? firmware);
            message = "This version of NVIDIA driver does not provide a GSP firmware.";
          }

          {
            assertion = useOpenModules -> (cfg.package ? open);
            message = "This version of NVIDIA driver does not provide a corresponding opensource kernel driver.";
          }

          {
            assertion = useOpenModules -> cfg.gsp.enable;
            message = "The GSP cannot be disabled when using the opensource kernel driver.";
          }

          {
            assertion =
              cfg.powerManagement.kernelSuspendNotifier
              -> (useOpenModules && lib.versionAtLeast cfg.package.version "595");
            message = "NVIDIA driver support for kernel suspend notifiers requires NVIDIA driver version 595 or newer, and the open source kernel modules.";
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

          "modprobe.d/nvidia-power-management-finegrained.conf" = lib.mkIf cfg.powerManagement.finegrained {
            text = ''
              options nvidia "NVreg_DynamicPowerManagement=0x02"
            '';
          };

          "nvidia/nvidia-application-profiles-rc" = lib.mkIf cfg.package.useProfiles {
            source = "${cfg.package.bin}/share/nvidia/nvidia-application-profiles-rc";
          };

          # 'cfg.package' installs it's files to /run/opengl-driver/...
          "egl/egl_external_platform.d".source = "/run/opengl-driver/share/egl/egl_external_platform.d/";
        };

        # reverse sync implies offloading
        hardware.nvidia.prime.offload.enable = lib.mkDefault reverseSyncCfg.enable;

        boot = {
          extraModulePackages = if useOpenModules then [ cfg.package.open ] else [ cfg.package.bin ];

          # nvidia-uvm is required by CUDA applications.
          # Exception is the open-source kernel module failing to load nvidia-uvm using softdep
          # for unknown reasons.
          # It affects CUDA: https://github.com/NixOS/nixpkgs/issues/334180
          # Previously nvidia-uvm was explicitly loaded only when xserver was enabled:
          # https://github.com/NixOS/nixpkgs/pull/334340/commits/4548c392862115359e50860bcf658cfa8715bde9
          # We are now loading the module eagerly for all users of the open driver (including headless).
          kernelModules = [
            "nvidia"
            "nvidia_modeset"
            "nvidia_drm"
          ]
          ++ lib.optionals useOpenModules [ "nvidia_uvm" ];

          kernelParams =
            lib.optional useOpenModules "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1"
            ++ lib.optional (
              cfg.powerManagement.enable && cfg.powerManagement.kernelSuspendNotifier
            ) "nvidia.NVreg_UseKernelSuspendNotifiers=1"
            ++ lib.optional cfg.powerManagement.enable "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
            ++ lib.optional (config.boot.kernelPackages.kernel.kernelAtLeast "6.2" && !ibtSupport) "ibt=off"
            ++ lib.optional useModeset "nvidia-drm.modeset=1"
            ++ lib.optional (
              useModeset && lib.versionAtLeast cfg.package.version "545"
            ) "nvidia-drm.fbdev=1";
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
          ''
          + lib.optionalString cfg.powerManagement.finegrained (
              lib.optionalString (lib.versionOlder config.boot.kernelPackages.kernel.version "5.5") ''
                # Remove NVIDIA USB xHCI Host Controller devices, if present
                ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

                # Remove NVIDIA USB Type-C UCSI devices, if present
                ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

                # Remove NVIDIA Audio devices, if present
                ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"
              ''
              + ''
                # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
                ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
                ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

                # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
                ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
                ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
              ''
            )
          )
        ];

        hardware.graphics = {
          extraPackages = [
            cfg.package.out
            (combineIcdPkgs pkgs)
          ]
          ++ lib.optional cfg.videoAcceleration pkgs.nvidia-vaapi-driver;
          extraPackages32 = [
            cfg.package.lib32
            (combineIcdPkgs pkgs.pkgsi686Linux)
          ];
        };
        hardware.firmware = lib.optional cfg.gsp.enable cfg.package.firmware;

        providers.resumeAndSuspend.hooks = lib.mkIf (cfg.powerManagement.enable && !cfg.powerManagement.kernelSuspendNotifier) {
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
            priority = 900; # run after other resume hooks
          };
        };

        environment.systemPackages = [ cfg.package.bin ]
          ++ lib.optional offloadCfg.enableOffloadCmd (
              pkgs.writeShellScriptBin offloadCfg.offloadCmdMainProgram ''
                export __NV_PRIME_RENDER_OFFLOAD=1
                export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
                export __GLX_VENDOR_LIBRARY_NAME=nvidia
                export __VK_LAYER_NV_optimus=NVIDIA_only
                exec "$@"
              ''
            );
  };
}
