{ config, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.iso9660 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `iso9660` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `iso9660` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.iso9660 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `iso9660` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `iso9660`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.iso9660.enable {
    boot.initrd.kernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.iso9660.enable [
      "isofs"
    ];
  };
}
