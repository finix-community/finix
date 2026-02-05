{ lib, ... }:
{
  options = {
    boot.supportedFilesystems.efivarfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `efivarfs` filesystem.
        '';
      };
    };
  };
}
