{
  config,
  pkgs,
  lib,
  utils,
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
      boot.zfs.importPools = lib.unique (
        lib.concatMap (
          {
            device,
            fsType,
            neededForBoot,
            ...
          }:
          let
            pool = lib.head (lib.splitString "/" device);
          in
          lib.optional (neededForBoot && fsType == "zfs") (if pool == "" then device else pool)
        ) (lib.attrValues config.fileSystems)
      );
    }

    (lib.mkIf config.boot.supportedFilesystems.zfs.enable {
      boot.kernelModules = [ "zfs" ];

      boot.extraModulePackages = [
        config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute}
      ];
    })

    (lib.mkIf config.boot.initrd.supportedFilesystems.zfs.enable (
      let
        keysFor = pool: lib.filter (k: lib.head (lib.splitString "/" k) == pool) config.boot.zfs.loadKeys;
      in
      {
        boot.initrd = {
          kernelModules = [ "zfs" ];

          finit.tasks = lib.genAttrs' config.boot.zfs.importPools (
            pool:
            lib.nameValuePair "zpool-import-${utils.escapePath pool}" {
              conditions =
                lib.optionals config.services.mdevd.enable [ "run/coldplug/success" ]
                ++ lib.optionals config.services.gardendevd.enable [ "run/gardendevctl:2/success" ]
                ++ lib.optionals config.services.udev.enable [ "run/udevadm:5/success" ]
                ++ lib.optionals config.services.keventd.enable [ "service/keventd/ready" ];
              tty = "@console";
              script = ''
                # 90s total timeout, polled every 0.1s (busybox sleep supports fractional)
                tries=900
                i=0
                while [ "$i" -lt "$tries" ]; do
                  if zpool list "${pool}" >/dev/null 2>&1 || zpool import -f "${pool}"; then
                    ${lib.concatMapStringsSep "\n" (k: ''zfs load-key "${k}"'') (keysFor pool)}
                    exit 0
                  fi
                  i=$((i + 1))
                  sleep 0.1
                done

                printf 'zpool-import-${pool}: failed to import "${pool}" after 90s\n' >&2
                exit 1
              '';
            }
          );
        };
      }
    ))
  ];
}
