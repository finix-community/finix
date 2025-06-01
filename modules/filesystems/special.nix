{ lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems."none" = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    boot.supportedFilesystems."none" = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };
}
