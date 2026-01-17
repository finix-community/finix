{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.ext4 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `ext4` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `ext4` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.ext4 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `ext4` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = ''
          Packages providing filesystem utilities for `ext4`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems.ext4.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.ext4.enable [
      "ext4"
    ];

    boot.supportedFilesystems.ext4.packages = [ pkgs.e2fsprogs ];
    boot.initrd.supportedFilesystems.ext4.packages = [ pkgs.e2fsprogs ];
  };
}
