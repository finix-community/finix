{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.f2fs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `f2fs` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `f2fs` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.f2fs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `f2fs` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `f2fs`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.f2fs.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.f2fs.enable [
      "f2fs"
    ];

    boot.supportedFilesystems.f2fs.packages = [ pkgs.f2fs-tools ];
    boot.initrd.supportedFilesystems.f2fs.packages = [ pkgs.f2fs-tools ];
  };
}
