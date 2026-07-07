{ config, lib, pkgs }:
let
  cfg = config.hardware.nvidia;

  icd = [
    "egl-wayland"
  ]
  ++ lib.optionals (lib.versionAtLeast cfg.package.version "495") [
    "egl-gbm"
  ]
  ++ lib.optionals (lib.versionAtLeast cfg.package.version "560") [
    "egl-wayland2"
    "egl-x11"
  ];
in
{
  inherit cfg icd;

  ibtSupport = (cfg.kernelModule == "open") || (cfg.package.ibtSupport or false);

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

  igpuId =
    if cfg.prime.intelBusId != null then "modesetting"
    else if cfg.prime.amdgpuBusId != null then "amdgpu"
    else null;
}