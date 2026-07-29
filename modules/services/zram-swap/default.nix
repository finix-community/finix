{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zram-swap;
in
{
  options.services.zram-swap = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable swap on a compressed zram block device.
      '';
    };

    memoryPercent = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = ''
        Size of the zram device as a percentage of total memory.
      '';
    };

    algorithm = lib.mkOption {
      type = lib.types.str;
      default = "zstd";
      example = "lz4";
      description = ''
        Compression algorithm passed to {command}`zramctl`.
      '';
    };

    priority = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = ''
        Swap priority of the zram device. Higher values are preferred by
        the kernel over lower-priority swap devices.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "zram" ];

    finit.tasks.zram-swap = {
      description = "zram swap (${toString cfg.memoryPercent}% RAM, ${cfg.algorithm})";
      log = true;
      command = pkgs.writeShellScript "zram-swap" ''
        set -eu
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.util-linux
            pkgs.gnugrep
            pkgs.gawk
            pkgs.kmod
          ]
        }
        modprobe zram || true
        grep -q zram /proc/swaps && exit 0
        mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        dev=$(zramctl --find --size "$((mem_kb * ${toString cfg.memoryPercent} / 100))K" --algorithm ${cfg.algorithm})
        mkswap "$dev" >/dev/null
        swapon -p ${toString cfg.priority} "$dev"
      '';
    };
  };
}
