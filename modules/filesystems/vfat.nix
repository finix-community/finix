{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.vfat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `vfat` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `vfat` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.vfat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `vfat` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `vfat`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.vfat.enable {
    boot.initrd.kernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.vfat.enable [
      "vfat"
      "nls_cp437"
      "nls_iso8859-1"
    ];

    boot.supportedFilesystems.vfat.packages = [
      pkgs.dosfstools
      pkgs.mtools
    ];
    boot.initrd.supportedFilesystems.vfat.packages = [ pkgs.dosfstools ];
  };
}
