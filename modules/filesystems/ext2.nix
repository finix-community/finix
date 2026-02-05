{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.ext2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `ext2` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `ext2` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.ext2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `ext2` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `ext2`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.ext2.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.ext2.enable [
      "ext2"
    ];

    boot.supportedFilesystems.ext2.packages = [ pkgs.e2fsprogs ];
    boot.initrd.supportedFilesystems.ext2.packages = [ pkgs.e2fsprogs ];
  };
}
