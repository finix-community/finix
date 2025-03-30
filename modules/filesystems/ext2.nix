{ config, pkgs, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.ext2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.ext2 = {
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

  config = lib.mkIf config.boot.supportedFilesystems.ext2.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.ext2.enable [
      "ext2"
    ];

    boot.supportedFilesystems.ext2.packages = [ pkgs.e2fsprogs ];
    boot.initrd.supportedFilesystems.ext2.packages = [ pkgs.e2fsprogs ];
  };
}
