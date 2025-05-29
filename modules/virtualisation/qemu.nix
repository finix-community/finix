{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption mkPackageOption types;

  qemuCommand =
    qemuPkg:
    let
      hostStdenv = qemuPkg.stdenv;
      hostSystem = hostStdenv.system;
      guestSystem = pkgs.stdenv.hostPlatform.system;

      linuxHostGuestMatrix = {
        x86_64-linux = [
          "${qemuPkg}/bin/qemu-system-x86_64"
          "-machine"
          "accel=kvm:tcg"
          "-cpu"
          "max"
        ];
        armv7l-linux = [
          "${qemuPkg}/bin/qemu-system-arm"
          "-machine"
          "virt,accel=kvm:tcg"
          "-cpu"
          "max"
        ];
        aarch64-linux = [
          "${qemuPkg}/bin/qemu-system-aarch64"
          "-machine"
          "virt,gic-version=max,accel=kvm:tcg"
          "-cpu"
          "max"
        ];
        powerpc64le-linux = [
          "${qemuPkg}/bin/qemu-system-ppc64"
          "-machine"
          "powernv"
        ];
        powerpc64-linux = [
          "${qemuPkg}/bin/qemu-system-ppc64"
          "-machine"
          "powernv"
        ];
        riscv32-linux = [
          "${qemuPkg}/bin/qemu-system-riscv32"
          "-machine"
          "virt"
        ];
        riscv64-linux = [
          "${qemuPkg}/bin/qemu-system-riscv64"
          "-machine"
          "virt"
        ];
        x86_64-darwin = [
          "${qemuPkg}/bin/qemu-system-x86_64"
          "-machine"
          "accel=kvm:tcg"
          "-cpu"
          "max"
        ];
      };
      otherHostGuestMatrix = {
        aarch64-darwin = {
          aarch64-linux = [
            "${qemuPkg}/bin/qemu-system-aarch64"
            "-machine"
            "virt,gic-version=2,accel=hvf:tcg"
            "-cpu"
            "max"
          ];
          inherit (otherHostGuestMatrix.x86_64-darwin) x86_64-linux;
        };
        x86_64-darwin = {
          x86_64-linux = [
            "${qemuPkg}/bin/qemu-system-x86_64"
            "-machine"
            "type=q35,accel=hvf:tcg"
            "-cpu"
            "max"
          ];
        };
      };

      throwUnsupportedHostSystem =
        let
          supportedSystems = [ "linux" ] ++ (lib.attrNames otherHostGuestMatrix);
        in
        throw "Unsupported host system ${hostSystem}, supported: ${lib.concatStringsSep ", " supportedSystems}";
      throwUnsupportedGuestSystem =
        guestMap:
        throw "Unsupported guest system ${guestSystem} for host ${hostSystem}, supported: ${lib.concatStringsSep ", " (lib.attrNames guestMap)}";
    in
    if hostStdenv.hostPlatform.isLinux then
      linuxHostGuestMatrix.${guestSystem} or "${qemuPkg}/bin/qemu-kvm"
    else
      let
        guestMap = (otherHostGuestMatrix.${hostSystem} or throwUnsupportedHostSystem);
      in
      (guestMap.${guestSystem} or (throwUnsupportedGuestSystem guestMap));

  cfg = config.virtualisation.qemu;

  bootModeArgs = {
    kernel = [
      "-kernel"
      "${config.boot.kernelPackages.kernel}/bzImage"
      "-initrd"
      "${config.boot.initrd.package}/initrd"
      "-append"
      (toString config.boot.kernelParams)
    ];
  };
in
{
  imports = [ ./common.nix ];

  options = {
    virtualisation.qemu = {
      package = mkPackageOption pkgs [ "qemu" ] { };

      bootMode = mkOption {
        type = types.enum [ "kernel" ]; # ++ [ "bios" "uefi" ];
        default = "kernel";
        description = ''
          Boot method used to load the guest.
        '';
      };

      argv = mkOption {
        type = types.listOf types.str;
        readOnly = true;
        description = ''
          Command-line for starting the host QEMU.
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        description = ''
          Extra command-line options for starting the host QEMU.
        '';
      };

    };
  };

  config = {
    virtualisation.qemu.argv =
      (qemuCommand cfg.package)
      ++ bootModeArgs.${cfg.bootMode}
      ++ [
        "-m"
        (toString config.virtualisation.memorySize)
        "-smp"
        (toString config.virtualisation.cores)
      ] ++ cfg.extraArgs;
  };
}
