{ lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable support for the `tmpfs` filesystem in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable support for the `tmpfs` filesystem.
        '';
      };
    };
  };
}
