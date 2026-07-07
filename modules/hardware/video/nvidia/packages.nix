{ config, lib, pkgs, ... }:
let
  common = import ./common.nix { inherit config lib pkgs; };
  inherit (common) cfg combineIcdPkgs offloadScript;
in
{
  config = lib.mkIf cfg.enable {
    environment.etc."nvidia/nvidia-application-profiles-rc" = lib.mkIf cfg.package.useProfiles {
      source = "${cfg.package.bin}/share/nvidia/nvidia-application-profiles-rc";
    };

    environment.etc."egl/egl_external_platform.d".source =
      "/run/opengl-driver/share/egl/egl_external_platform.d/";

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

    environment.systemPackages =
      [ cfg.package.bin ]
      ++ lib.optionals cfg.nvidiaSettings [ cfg.package.settings ]
      ++ lib.optionals cfg.prime.offload.enableOffloadCmd [ offloadScript ];
  };
}