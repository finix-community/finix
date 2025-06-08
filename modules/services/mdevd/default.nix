{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  writeExeclineScript = pkgs.execline.passthru.writeScript;
  gidOf = name: toString config.ids.gids.${name};

  cfg = config.services.mdevd;

  # Insert modules for devices.
  modaliasRule = "$MODALIAS=.* 0:0 660 +importas m MODALIAS modprobe --quiet $m";

  devDiskScript = writeExeclineScript "mdevd-disk.el" "" ''
    importas -S ACTION
    importas -S MDEV
    case $ACTION
    {
      add {
        # Udev compatibility hack.
        foreground { mkdir -p /dev/disk/by-id }
        foreground { ln -s ../../$MDEV /dev/disk/by-id/$MDEV }

        forbacktickx -pE LINE { blkid --output export /dev/$MDEV }
        case -N $LINE {
          ^LABEL=(.*) {
            foreground { mkdir -p /dev/disk/by-label }
            ln -s ../../$MDEV /dev/disk/by-label/$1
          }
           ^UUID=(.*) {
            foreground { mkdir -p /dev/disk/by-uuid }
             ln -s ../../$MDEV /dev/disk/by-uuid/$1
           }
        }
      }
      remove {
        foreground { rm -f /dev/disk/by-id/$MDEV }
        forbacktickx -pE LINE { blkid --output export /dev/$MDEV }
        case -N $LINE {
          ^LABEL=(.*) { rm -f /dev/disk/by-label/$1 }
           ^UUID=(.*) { rm -f /dev/disk/by-uuid/$1  }
        }
      }
    }
  '';

  # Create symlinks in /dev/disk/.
  # Requires blkid from util-linux be on $PATH.
  devDiskRule = "SUBSYSTEM=block;.* 0:${gidOf "disk"} 660 &${devDiskScript}";
in
{
  options.services.mdevd = {
    enable = mkEnableOption "the mdevd device hotplug manager";

    package = mkPackageOption pkgs [ "mdevd" ] { };

    hotplugRules = mkOption {
      type = types.listOf types.str;
      description = ''
        Mdevd rules for hotplug events.
        These rules are active after the initial `mdevd` daemon
        has coldbooted with the `services.mdevd.coldplug` rules.
      '';
    };

    coldplugRules = mkOption {
      type = types.listOf types.str;
      description = ''
        Mdeved rules for coldplug events during the initramfs stage of booting.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.mdevd = {
      hotplugRules = [
        modaliasRule
        devDiskRule
      ];
      coldplugRules = [
        modaliasRule
        devDiskRule
      ];
    };
    boot.initrd.contents = [
        { target = "/etc/mdev.conf";
          source = pkgs.writeText "mdev.conf"
            (lib.concatLines config.services.mdevd.coldplugRules);
        }
        { source = devDiskScript;
          target = "/etc/dev-disk.el";
        }
    ];
  };
}
