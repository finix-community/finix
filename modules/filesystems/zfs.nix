{ config, pkgs, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.zfs ];
      };
    };

    boot.supportedFilesystems.zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.zfs ];
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.boot.supportedFilesystems.zfs.enable {
      boot.kernelModules = [ "zfs" ];

      boot.extraModulePackages = [
        config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute}
      ];
    })

    (lib.mkIf config.boot.initrd.supportedFilesystems.zfs.enable {
      boot.initrd.kernelModules = [ "zfs" ];
    })
  ];
}
