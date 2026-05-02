{
  config,
  pkgs,
  lib,
  ...
}: 
{
  options = {
    boot.initrd.supportedFilesystems.lvm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable LVM support in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [pkgs.lvm2];
        description = ''
          Packages providing LVM utilities in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.lvm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable LVM support.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [pkgs.lvm2];
        description = ''
          Packages providing lvm utilities.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.boot.supportedFilesystems.lvm.enable {
      boot.kernelModules = ["dm_mod"];
    })

    (lib.mkIf config.boot.initrd.supportedFilesystems.lvm.enable {
      boot.initrd.kernelModules = ["dm_mod"];

      boot.initrd.fileSystemImportCommands = lib.mkOrder 600 (
        if config.services.udev.enable || !config.services.mdevd.enable then
          "lvm vgchange -ay"
        else
          "lvm vgchange -ay --noudevsync\ndmsetup mknodes"
      );
    })
  ];
}
