{ config, pkgs, lib, ... }:
let
  cfg = config.boot.loader.limine;

  format = pkgs.formats.keyValue { };

  limineInstallConfig = pkgs.writeText "limine-install.json" (
    builtins.toJSON {
      inherit (cfg)
        additionalFiles
        biosDevice
        biosSupport
        efiSupport
        enrollConfig
        extraEntries
        force
        partitionIndex
        settings
        validateChecksums
      ;

      nixPath = config.services.nix-daemon.package;
      efiBootMgrPath = pkgs.efibootmgr;
      liminePath = cfg.package;
      efiMountPoint = config.boot.loader.efi.efiSysMountPoint;
      fileSystems = config.fileSystems;
      canTouchEfiVariables = config.boot.loader.efi.canTouchEfiVariables;
      efiRemovable = cfg.efiInstallAsRemovable;
      maxGenerations = if cfg.maxGenerations == null then 0 else cfg.maxGenerations;
      hostArchitecture = pkgs.stdenv.hostPlatform.parsed.cpu;
    }
  );
  defaultWallpaper = pkgs.nixos-artwork.wallpapers.simple-dark-gray-bootloader.gnomeFilePath;
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

  options.system.installBootLoader = lib.mkOption {
    internal = true;
    default = pkgs.writeShellScript "no-bootloader" ''
      echo 'Warning: do not know how to make this configuration bootable; please enable a boot loader.' 1>&2
    '';
    defaultText = lib.literalExpression ''
      pkgs.writeShellScript "no-bootloader" '''
        echo 'Warning: do not know how to make this configuration bootable; please enable a boot loader.' 1>&2
      '''
    '';
    description = ''
      A program that writes a bootloader installation script to the path passed in the first command line argument.

      See `pkgs/by-name/sw/switch-to-configuration-ng/src/src/main.rs`.
    '';
    type = with lib.types; either str package;
  };

  options.boot.loader.limine = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [limine](${pkgs.limine.meta.homepage}) as the system bootloader.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.limine;
      defaultText = lib.literalExpression "pkgs.limine";
      description = ''
        The package to use for `limine`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          timeout = lib.mkOption {
            type = with lib.types; either int (enum [ "no" ]);
            default = 5;
            description = ''
              Specifies the timeout in seconds before the first _entry_ is automatically booted. If set
              to `"no"`, disable automatic boot. If set to `0`, boots default entry instantly.
            '';
          };

          wallpaper = lib.mkOption {
            default = [ ];
            example = lib.literalExpression "[ pkgs.nixos-artwork.wallpapers.simple-dark-gray-bootloader.gnomeFilePath ]";
            type = with lib.types; listOf path;
            description = ''
              A list of wallpapers.
              If more than one is specified, a random one will be selected at boot.
            '';
          };

          wallpaper_style = lib.mkOption {
            type = lib.types.enum [ "centered" "streched" "tiled" ];
            default = "streched";
            description = ''
              The style which will be used to display the wallpaper image.
            '';
          };

          hash_mismatch_panic = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              If set to `false`, do not panic if there is a hash mismatch for a file, but print a warning instead.
            '';
          };

          editor_enabled = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              If set to `false`, the editor will not be accessible.

              ::: {.note}
              It is recommended to set this to `false`, as it allows gaining `root`
              access by passing `init=/bin/sh` as a kernel parameter.
              :::
            '';
          };
        };
      };
      default = { };
      description = ''
        `limine` configuration. See [upstream documentation](https://codeberg.org/Limine/Limine/src/branch/v${lib.versions.major cfg.package.version}.x/CONFIG.md)
        for additional details.
      '';
    };

    maxGenerations = lib.mkOption {
      default = null;
      example = 50;
      type = lib.types.nullOr lib.types.int;
      description = ''
        Maximum number of latest generations in the boot menu.
        Useful to prevent boot partition of running out of disk space.
        `null` means no limit i.e. all generations that were not
        garbage collected yet.
      '';
    };

    extraEntries = lib.mkOption {
      default = "";
      type = lib.types.lines;
      example = lib.literalExpression ''
        /memtest86
          protocol: chainload
          path: boot():///efi/memtest86/memtest86.efi
      '';
      description = ''
        A string which is appended to the end of limine.conf. The config format can be found [here](https://codeberg.org/Limine/Limine/src/branch/v${lib.versions.major cfg.package.version}.x/CONFIG.md).
      '';
    };

    additionalFiles = lib.mkOption {
      default = { };
      type = lib.types.attrsOf lib.types.path;
      example = lib.literalExpression ''
        { "efi/memtest86/memtest86.efi" = "''${pkgs.memtest86-efi}/BOOTX64.efi"; }
      '';
      description = ''
        A set of files to be copied to {file}`/boot`. Each attribute name denotes the
        destination file name in {file}`/boot`, while the corresponding attribute value
        specifies the source file.
      '';
    };

    validateChecksums = lib.mkEnableOption null // {
      default = true;
      description = ''
        Whether to validate file checksums before booting.
      '';
    };

    efiSupport = lib.mkEnableOption null // {
      default = pkgs.stdenv.hostPlatform.isEfi;
      defaultText = lib.literalExpression "pkgs.stdenv.hostPlatform.isEfi";
      description = ''
        Whether or not to install the limine EFI files.
      '';
    };

    efiInstallAsRemovable = lib.mkEnableOption null // {
      default = !config.boot.loader.efi.canTouchEfiVariables;
      defaultText = lib.literalExpression "!config.boot.loader.efi.canTouchEfiVariables";
      description = ''
        Whether or not to install the limine EFI files as removable.

        See {option}`boot.loader.grub.efiInstallAsRemovable`
      '';
    };

    biosSupport = lib.mkEnableOption null // {
      default = !cfg.efiSupport && pkgs.stdenv.hostPlatform.isx86;
      defaultText = lib.literalExpression "!config.boot.loader.limine.efiSupport && pkgs.stdenv.hostPlatform.isx86";
      description = ''
        Whether or not to install limine for BIOS.
      '';
    };

    biosDevice = lib.mkOption {
      default = "nodev";
      type = lib.types.str;
      description = ''
        Device to install the BIOS version of limine on.
      '';
    };

    partitionIndex = lib.mkOption {
      default = null;
      type = lib.types.nullOr lib.types.int;
      description = ''
        The 1-based index of the dedicated partition for limine's second stage.
      '';
    };

    enrollConfig = lib.mkEnableOption null // {
      default = cfg.settings.hash_mismatch_panic;
      defaultText = lib.literalExpression "boot.loader.limine.settings.hash_mismatch_panic";
      description = ''
        Whether or not to enroll the config.
        Only works on EFI!
      '';
    };

    force = lib.mkEnableOption null // {
      description = ''
        Force installation even if the safety checks fail, use absolutely only if necessary!
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = pkgs.stdenv.hostPlatform.isx86_64 || pkgs.stdenv.hostPlatform.isi686 || pkgs.stdenv.hostPlatform.isAarch64;
        message = "Limine can only be installed on aarch64 & x86 platforms";
      }
      { assertion = cfg.efiSupport || cfg.biosSupport;
        message = "Both UEFI support and BIOS support for Limine are disabled, this will result in an unbootable system";
      }
    ];

    # TODO: move these somewhere more appropriate
    boot.supportedFilesystems.efivarfs.enable = lib.mkIf config.boot.loader.efi.canTouchEfiVariables true;
    fileSystems."/sys/firmware/efi/efivars" = lib.mkIf config.boot.loader.efi.canTouchEfiVariables {
      device = "efivarfs";
      fsType = "efivarfs";
      options = [ "defaults" "nofail" ];
    };

    boot.loader.limine.settings = {
      graphics = true;
      verbose = lib.mkIf cfg.debug true;

      wallpaper = lib.mkDefault [ defaultWallpaper ];
      backdrop = lib.mkDefault "2F302F";
      wallpaper_style = lib.mkDefault "streched";
    };

    system.installBootLoader = pkgs.replaceVarsWith {
      src = ./limine-install.py;
      isExecutable = true;
      replacements = {
        python3 = pkgs.python3.withPackages (python-packages: [ python-packages.psutil ]);
        configPath = limineInstallConfig;
      };
    };
  };
}
