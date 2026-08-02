{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (import ./common.nix { inherit lib config; }) cfg combineIcdPkgs;
in
{
  config = lib.mkIf cfg.enable {
    environment.etc = {
      "nvidia/nvidia-application-profiles-rc" = lib.mkIf cfg.package.useProfiles {
        source = "${cfg.package.bin}/share/nvidia/nvidia-application-profiles-rc";
      };

      # 'cfg.package' installs it's files to /run/opengl-driver/...
      "egl/egl_external_platform.d".source = "/run/opengl-driver/share/egl/egl_external_platform.d/";
    };

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

    environment.systemPackages = [ cfg.package.bin ];
  };
}
