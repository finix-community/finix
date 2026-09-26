{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.virtualisation.android;
in
{
  options.virtualisation.android.enable = lib.mkEnableOption "Android container support (Waydroid)";

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "binder_linux"
      "ashmem_linux"
    ];

    services.dbus.packages = [ pkgs.waydroid-nftables ];
  };
}
