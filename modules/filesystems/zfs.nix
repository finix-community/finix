{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.initrd.supportedFilesystems.zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `zfs` filesystem in the initial ramdisk.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.zfs ];
        description = ''
          Packages providing filesystem utilities for `zfs` in the initial ramdisk.
        '';
      };
    };

    boot.supportedFilesystems.zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `zfs` filesystem.
        '';
      };

      packages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ pkgs.zfs ];
        description = ''
          Packages providing filesystem utilities for `zfs`.
        '';
      };
    };

    boot.zfs = {
      importPools = lib.mkOption {
        type = with lib.types; listOf str;
        description = ''
          List of ZFS pools to import at boot.
          Defaults to the pools necessary for booting.
        '';
        example = [
          "jug"
          "bucket"
        ];
      };
      loadKeys = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = ''
          List of ZFS dataset names to load keys for during boot.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      boot.zfs.importPools =
        with builtins;
        config.fileSystems
        |> attrValues
        |> filter ({ neededForBoot, fsType, ... }: neededForBoot && fsType == "zfs")
        |> map (
          { device, ... }:
          let
            pool = device |> lib.splitString "/" |> head;
          in
          if pool == "" then device else pool
        )
        |> lib.unique;
    }
    (lib.mkIf config.boot.supportedFilesystems.zfs.enable {
      boot.kernelModules = [ "zfs" ];

      boot.extraModulePackages = [
        config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute}
      ];
    })

    (lib.mkIf config.boot.initrd.supportedFilesystems.zfs.enable {
      boot.initrd = {
        kernelModules = [ "zfs" ];
        fileSystemImportCommands =
          map (name: "zpool import -f ${name}") config.boot.zfs.importPools
          ++ map (name: "zfs load-key ${name}") config.boot.zfs.loadKeys
          |> (lib.concatStringsSep "\n");
      };
    })
  ];
}
