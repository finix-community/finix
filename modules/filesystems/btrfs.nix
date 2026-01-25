{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.btrfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `btrfs` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.btrfs-progs ];
        description = ''
          Packages providing filesystem utilities for `btrfs` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.btrfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `btrfs` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.btrfs-progs ];
        description = ''
          Packages providing filesystem utilities for `btrfs`.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.initrd.supportedFilesystems.btrfs.enable {
    boot.initrd.kernelModules = [ "btrfs" ];
    boot.initrd.availableKernelModules = [
      "crc32c"
    ]
    ++ lib.optionals (config.boot.kernelPackages.kernel.kernelAtLeast "5.5") [
      "xxhash_generic"
      "blake2b_generic"
      "sha256_generic"
    ];
  };
}
