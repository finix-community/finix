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
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.xfsprogs.bin ];
      };
    };

    boot.supportedFilesystems.xfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.xfsprogs ];
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
