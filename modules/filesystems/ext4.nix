{ config, pkgs, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.ext4 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.ext4 = {
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

  config = lib.mkIf config.boot.supportedFilesystems.ext4.enable {
    boot.initrd.availableKernelModules = lib.mkIf config.boot.initrd.supportedFilesystems.ext4.enable [
      "ext4"
    ];

    boot.supportedFilesystems.ext4.packages = [ pkgs.e2fsprogs ];
    boot.initrd.supportedFilesystems.ext4.packages = [ pkgs.e2fsprogs ];
  };
}
