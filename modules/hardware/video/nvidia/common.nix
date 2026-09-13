{ lib, config }:
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
in
{
  inherit
    cfg
    ibtSupport
    icd
    combineIcdPkgs
    ;
}
