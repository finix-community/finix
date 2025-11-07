{ lib, ... }:
{
  options = {
    boot.supportedFilesystems.efivarfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
}
