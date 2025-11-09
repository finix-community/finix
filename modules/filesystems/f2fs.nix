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
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.f2fs = {
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

  config = lib.mkIf config.boot.supportedFilesystems.f2fs.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.f2fs.enable [
      "f2fs"
    ];

    boot.supportedFilesystems.f2fs.packages = [ pkgs.f2fs-tools ];
    boot.initrd.supportedFilesystems.f2fs.packages = [ pkgs.f2fs-tools ];
  };
}
