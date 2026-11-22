{ config, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.overlay = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `overlay` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `overlay` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.overlay = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `overlay` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `overlay`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.overlay.enable {
    boot.initrd.kernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.overlay.enable [
      "overlay"
    ];
  };
}
