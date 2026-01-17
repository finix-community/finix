{ lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems."none" = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable support for bind mounts in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems."none" = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable support for bind mounts.
        '';
      };
    };
  };
}
