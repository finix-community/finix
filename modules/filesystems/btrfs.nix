{ config, pkgs, lib, ... }:
{
  options = {
    boot.initrd.supportedFilesystems.btrfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.btrfs-progs ];
      };
    };

    boot.supportedFilesystems.btrfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.btrfs-progs ];
      };
    };
  };

  config = lib.mkIf config.boot.initrd.supportedFilesystems.btrfs.enable {
    boot.initrd.kernelModules = [ "btrfs" ];
    boot.initrd.availableKernelModules =
      [] # [ "crc32c" ]
      ++ lib.optionals (config.boot.kernelPackages.kernel.kernelAtLeast "5.5") [
        "xxhash_generic"
        "blake2b_generic"
        "sha256_generic"
      ];
  };
}
