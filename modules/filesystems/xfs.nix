{ config, pkgs, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.xfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.xfs = {
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

  config = lib.mkIf config.boot.supportedFilesystems.xfs.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.xfs.enable [
      "xfs"
      "crc32c"
    ];

    boot.supportedFilesystems.xfs.packages = [ pkgs.xfsprogs ];
    boot.initrd.supportedFilesystems.xfs.packages = [ pkgs.xfsprogs.bin ];
  };
}
