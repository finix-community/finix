{
  config,
  lib,
  ...
}:
let
  cfg = config.boot.loader.efi;
in
{
  options.boot.loader.efi = {
    canTouchEfiVariables = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Whether the installation process is allowed to modify EFI boot variables.";
    };

    efiSysMountPoint = lib.mkOption {
      default = "/boot";
      type = lib.types.str;
      description = "Where the EFI System Partition is mounted.";
    };
  };

  config = lib.mkIf cfg.canTouchEfiVariables {
    boot.supportedFilesystems.efivarfs.enable = true;

    fileSystems."/sys/firmware/efi/efivars" = {
      device = "efivarfs";
      fsType = "efivarfs";
      options = [
        "defaults"
        "nofail"
      ];
    };
  };
}
