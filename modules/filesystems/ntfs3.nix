{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.ntfs3 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.ntfs3 = {
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

  config = lib.mkIf config.boot.supportedFilesystems.ntfs3.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.ntfs3.enable [
      "ntfs3"
    ];

    boot.supportedFilesystems.ext4.packages = [ pkgs.scrounge-ntfs3 ];
  };
}
