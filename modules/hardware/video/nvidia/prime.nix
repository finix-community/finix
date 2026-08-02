{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware.nvidia.prime;

  gpuIDs = lib.filter (x: x != null) [
    cfg.intelBusId
    cfg.nvidiaBusId
    cfg.amdgpuBusId
  ];

  busIdType = lib.types.strMatching "([[:print:]]+[:@][0-9]{1,3}:[0-9]{1,2}:[0-9])?";
in
{
  options.hardware.nvidia.prime = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.offload.enable || cfg.sync.enable;
      defaultText = lib.literalExpression "config.hardware.nvidia.prime.offload.enable || config.hardware.nvidia.prime.sync.enable";
      readOnly = true;
      description = ''
        Whether to enable nvidia PRIME support.
      '';
    };

    offload.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable PRIME offload mode. The iGPU handles display output
        and general rendering; the NVIDIA GPU is used only when explicitly
        requested (via the nvidia-offload wrapper or DRI_PRIME env var).
        Cannot be used together with prime.sync.enable.
      '';
    };

    offload.enableOffloadCmd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to add an `nvidia-offload` wrapper script to systemPackages.
        Run `nvidia-offload <program>` to launch a program on the NVIDIA GPU.
        Requires prime.offload.enable = true.
      '';
    };

    sync.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable PRIME sync mode. Both GPUs are active simultaneously;
        the NVIDIA GPU renders and the iGPU handles display. Eliminates tearing
        but uses more power than offload mode. Cannot be used with
        prime.offload.enable.
      '';
    };

    intelBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:0:2:0";
      description = ''
        The PCI bus ID of the Intel iGPU. Find it with:
          lspci | grep -i intel | grep -i vga
        then convert the hex address (e.g. 00:02.0) to PCI:0:2:0.
      '';
    };

    nvidiaBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:1:0:0";
      description = ''
        The PCI bus ID of the NVIDIA GPU. Find it with:
          lspci | grep -i nvidia
        then convert the hex address (e.g. 01:00.0) to PCI:1:0:0.
      '';
    };

    amdgpuBusId = lib.mkOption {
      type = lib.types.nullOr busIdType;
      default = null;
      example = "PCI:4:0:0";
      description = ''
        The PCI bus ID of the AMD iGPU (for AMD+NVIDIA Optimus laptops).
        Find it with: lspci | grep -i amd | grep -i vga
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.offload.enable && cfg.sync.enable);
        message = "config.hardware.nvidia.prime.offload.enable and config.hardware.nvidia.prime.sync.enable are mutually exclusive";
      }
      {
        assertion = cfg.offload.enableOffloadCmd -> cfg.offload.enable;
        message = "config.hardware.nvidia.prime.offload.enableOffloadCmd requires config.hardware.nvidia.prime.offload.enable = true";
      }
      {
        assertion = cfg.enable -> (cfg.nvidiaBusId != null && lib.length gpuIDs >= 2);
        message = "PRIME requires config.hardware.nvidia.prime.nvidiaBusId and at least one of config.hardware.nvidia.prime.intelBusId / config.hardware.nvidia.prime.amdgpuBusId to be set";
      }
    ];

    hardware.nvidia.enable = lib.mkForce true;

    environment.etc =
      let
        igpuId =
          if cfg.intelBusId != null then
            "modesetting"
          else if cfg.amdgpuBusId != null then
            "amdgpu"
          else
            null;
      in
      lib.mkIf config.programs.xorg.enable or false {
        "X11/xorg.conf.d/10-nvidia-prime.conf".text =
          lib.optionalString (cfg.intelBusId != null) ''
            Section "Device"
              Identifier "modesetting"
              Driver "modesetting"
              BusID "${cfg.intelBusId}"
              Option "DRI" "3"
            EndSection
          ''
          + lib.optionalString (cfg.amdgpuBusId != null) ''
            Section "Device"
              Identifier "amdgpu"
              Driver "amdgpu"
              BusID "${cfg.amdgpuBusId}"
            EndSection
          ''
          + lib.optionalString (cfg.nvidiaBusId != null) ''
            Section "Device"
              Identifier "nvidia"
              Driver "nvidia"
              BusID "${cfg.nvidiaBusId}"
              ${lib.optionalString cfg.offload.enable ''Option "AllowEmptyInitialConfiguration"''}
            EndSection
          ''
          + lib.optionalString (cfg.sync.enable && igpuId != null) ''
            Section "ServerLayout"
              Identifier "layout"
              Screen "Screen-nvidia[0]"
              Inactive "${igpuId}"
              Option "AllowNVIDIAGPUScreens"
            EndSection
          '';
      };

    environment.systemPackages =
      let
        script = pkgs.writeShellScriptBin "nvidia-offload" ''
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export __VK_LAYER_NV_optimus=NVIDIA_only

          exec "$@"
        '';
      in
      lib.optionals cfg.offload.enableOffloadCmd [ script ];
  };
}
