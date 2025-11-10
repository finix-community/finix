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
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.vfat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
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
