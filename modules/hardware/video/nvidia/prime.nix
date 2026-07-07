{ config, lib, ... }:
let
  common = import ./common.nix { inherit config lib; pkgs = null; };
  inherit (common) cfg primeEnabled igpuId;

  mkBusIdSection = busId: driver: extra: ''
    Section "Device"
      Identifier "${driver}"
      Driver "${driver}"
      BusID "${busId}"
      ${extra}
    EndSection
  '';

  intelSection = lib.optionalString (cfg.prime.intelBusId != null) (
    mkBusIdSection cfg.prime.intelBusId "modesetting" ''
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

  syncLayout = lib.optionalString (cfg.prime.sync.enable && igpuId != null) ''
    Section "ServerLayout"
      Identifier "layout"
      Screen "Screen-nvidia[0]"
      Inactive "${igpuId}"
      Option "AllowNVIDIAGPUScreens"
    EndSection
  '';
in
{
  config = lib.mkIf (cfg.enable && primeEnabled) {
    environment.etc."X11/xorg.conf.d/10-nvidia-prime.conf".text = ''
      ${intelSection}
      ${amdSection}
      ${nvidiaSection}
      ${syncLayout}
    '';
  };
}