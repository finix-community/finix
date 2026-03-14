{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.xfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `xfs` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.xfsprogs.bin ];
        description = ''
          Packages providing filesystem utilities for `xfs` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.xfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `xfs` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.xfsprogs ];
        description = ''
          Packages providing filesystem utilities for `xfs`.
        '';
      };
    };
  };

  config = {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.xfs.enable [
      "xfs"
      "crc32c"
    ];
  };
}
