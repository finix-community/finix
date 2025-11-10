{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.zfs;

  snapshots = [
    "frequent"
    "hourly"
    "daily"
    "weekly"
    "monthly"
  ];
in
{
  options.services.zfs.autoSnapshot = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = ''
        Enable the (OpenSolaris-compatible) ZFS auto-snapshotting service.
        Note that you must set the `com.sun:auto-snapshot`
        property to `true` on all datasets which you wish
        to auto-snapshot.

        You can override a child dataset to use, or not use auto-snapshotting
        by setting its flag with the given interval:
        `zfs set com.sun:auto-snapshot:weekly=false DATASET`
      '';
    };

    flags = lib.mkOption {
      default = "-k -p";
      example = "-k -p --utc";
      type = lib.types.str;
      description = ''
        Flags to pass to the zfs-auto-snapshot command.

        Run `zfs-auto-snapshot` (without any arguments) to
        see available flags.

        If it's not too inconvenient for snapshots to have timestamps in UTC,
        it is suggested that you append `--utc` to the list
        of default options (see example).

        Otherwise, snapshot names can cause name conflicts or apparent time
        reversals due to daylight savings, timezone or other date/time changes.
      '';
    };

    frequent = lib.mkOption {
      default = 4;
      type = lib.types.int;
      description = ''
        Number of frequent (15-minute) auto-snapshots that you wish to keep.
      '';
    };

    hourly = lib.mkOption {
      default = 24;
      type = lib.types.int;
      description = ''
        Number of hourly auto-snapshots that you wish to keep.
      '';
    };

    daily = lib.mkOption {
      default = 7;
      type = lib.types.int;
      description = ''
        Number of daily auto-snapshots that you wish to keep.
      '';
    };

    weekly = lib.mkOption {
      default = 4;
      type = lib.types.int;
      description = ''
        Number of weekly auto-snapshots that you wish to keep.
      '';
    };

    monthly = lib.mkOption {
      default = 12;
      type = lib.types.int;
      description = ''
        Number of monthly auto-snapshots that you wish to keep.
      '';
    };
  };

  options.services.zfs.autoScrub = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    # TODO: share this type with options.providers.scheduler.tasks.*.interval
    interval = lib.mkOption {
      type = lib.types.str;
      default = "monthly";
      description = ''
        The interval at which this task should run its specified {option}`command`. Accepts either a
        standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

        If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
        to the `scheduler` implementation and execute exactly as specified.

        If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
        underlying `scheduler` implementation will use its features to decide when best to run.
      '';
    };

    pools = lib.mkOption {
      type = with lib.types; listOf nonEmptyStr;
      default = [ ];
      example = [ "tank" ];
      description = ''
        List of ZFS pools to periodically scrub. If empty, all pools will be scrubbed.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.autoSnapshot.enable {
      providers.scheduler.tasks = builtins.listToAttrs (
        map (name: {
          name = "zfs-snapshot-${name}";
          value = {
            command = "${pkgs.zfstools}/bin/zfs-auto-snapshot ${cfg.autoSnapshot.flags} ${name} ${
              toString cfg.autoSnapshot.${name}
            }";
            interval = if name == "frequent" then "0,15,30,45 * * * *" else name;
          };
        }) snapshots
      );
    })

    (lib.mkIf cfg.autoScrub.enable {
      providers.scheduler.tasks = {
        zfs-scrub = {
          inherit (cfg.autoScrub) interval;

          command = pkgs.writeShellScript "zfs-scrub.sh" ''
            ${pkgs.zfs}/bin/zpool scrub -w ${
              if cfg.autoScrub.pools != [ ] then
                (lib.concatStringsSep " " cfg.autoScrub.pools)
              else
                "$(${pkgs.zfs}/bin/zpool list -H -o name)"
            }
          '';
        };
      };
    })
  ];
}
