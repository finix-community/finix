{ lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    boot.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };
}
