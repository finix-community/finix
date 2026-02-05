{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.modprobeConfig;
in
{
  options.boot.modprobeConfig = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable `modprobe` config. This is useful for systems like containers which do not require a kernel.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."modules-load.d/finix.conf" = lib.mkIf config.finit.enable {
      text = ''
        set modprobe = ${pkgs.kmod}/bin/modprobe

        ${lib.concatStringsSep "\n" config.boot.kernelModules}
      '';
    };

    environment.etc."modprobe.d/ubuntu.conf".source = "${pkgs.kmod-blacklist-ubuntu}/modprobe.conf";
    environment.etc."modprobe.d/debian.conf".source = pkgs.kmod-debian-aliases;

    environment.systemPackages = [
      pkgs.kmod
    ];

    finit.tasks.modprobe = {
      command = "${pkgs.kmod}/bin/modprobe --all ${lib.concatStringsSep " " config.boot.kernelModules}";
      conditions = "service/syslogd/ready";
      runlevels = "12345789";
    };

    system.activation.scripts.modprobe = lib.stringAfter [ "specialfs" ] ''
      # Allow the kernel to find our wrapped modprobe (which searches
      # in the right location in the Nix store for kernel modules).
      # We need this when the kernel (or some module) auto-loads a
      # module.
      echo ${pkgs.kmod}/bin/modprobe > /proc/sys/kernel/modprobe
    '';
  };
}
