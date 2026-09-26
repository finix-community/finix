{ config, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.squashfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `squashfs` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `squashfs` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.squashfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `squashfs` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `squashfs`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.squashfs.enable {
    boot.initrd.kernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.squashfs.enable [
      "squashfs"
      "loop"
    ];
  };
}
