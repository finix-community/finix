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
        default = [ pkgs.lvm2 ];
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
        default = [ pkgs.lvm2 ];
        description = ''
          Packages providing lvm utilities.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.boot.supportedFilesystems.lvm.enable {
      boot.kernelModules = [ "dm_mod" ];
    })

    (lib.mkIf config.boot.initrd.supportedFilesystems.lvm.enable {
      boot.initrd.kernelModules = [ "dm_mod" ];

      boot.initrd.finit.tasks.lvm = {
        conditions =
          lib.optionals config.services.mdevd.enable [ "run/coldplug/success" ]
          ++ lib.optionals config.services.gardendevd.enable [ "run/gardendevctl:2/success" ]
          ++ lib.optionals config.services.udev.enable [ "run/udevadm:5/success" ]
          ++ lib.optionals config.services.keventd.enable [ "service/keventd/ready" ]
          ++ lib.optional config.boot.initrd.supportedFilesystems.luks.enable [ "task/luks/success" ];

        script = ''
          lvm vgchange -ay --noudevsync
          dmsetup mknodes
        '';
      };
    })
  ];
}
