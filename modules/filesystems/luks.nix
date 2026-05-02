{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.luks = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable LUKS encrypted device support in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [pkgs.cryptsetup];
        description = ''
          Packages providing LUKS utilities in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.luks = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable LUKS encrypted device support.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [pkgs.cryptsetup];
        description = ''
          Packages providing LUKS utilities.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.boot.initrd.supportedFilesystems.luks.enable {
      boot.initrd.availableKernelModules = [
        "dm_mod"
        "dm_crypt"
        "aes"
        "blowfish"
        "twofish"
        "serpent"
        "cbc"
        "xts"
        "lrw"
        "ecb"
        "sha1"
        "sha256"
        "sha512"
        "af_alg"
        "algif_skcipher"
        "cryptd"
        "input_leds"
      ] ++ lib.optionals (lib.versionOlder config.boot.kernelPackages.kernel.version "7.0") [ "aes_generic" ];

      boot.initrd.fileSystemImportCommands = lib.mkOrder 500 (lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: dev:
          let
            fsOpts = lib.concatStringsSep " " dev.options;
          in
          "cryptsetup open ${fsOpts} ${dev.device} ${name}"
        ) (lib.filterAttrs (_: fs: fs.fsType == "luks") config.fileSystems)
      ));
    })
  ];
}
