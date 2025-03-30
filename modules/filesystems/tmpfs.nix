{ lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };

    boot.supportedFilesystems.tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
      };
    };
  };
}
