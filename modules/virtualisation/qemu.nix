{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    flatten
    literalExpression
    mapAttrs'
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optional
    optionals
    types
    ;

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

  useBootLoader = cfg.bootMode != "kernel";

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

      sharedDirectories = mkOption {
        type = types.attrsOf (
          types.submodule {
            options.source = mkOption {
              type = types.str;
              description = "The path of the directory to share, can be a shell variable";
            };
            options.target = mkOption {
              type = types.path;
              description = "The mount point of the directory inside the virtual machine";
            };
            options.securityModel = mkOption {
              type = types.enum [
                "passthrough"
                "mapped-xattr"
                "mapped-file"
                "none"
              ];
              default = "mapped-xattr";
              description = ''
                The security model to use for this share:

                - `passthrough`: files are stored using the same credentials as they are created on the guest (this requires QEMU to run as root)
                - `mapped-xattr`: some of the file attributes like uid, gid, mode bits and link target are stored as file attributes
                - `mapped-file`: the attributes are stored in the hidden .virtfs_metadata directory. Directories exported by this security model cannot interact with other unix tools
                - `none`: same as "passthrough" except the sever won't report failures if it fails to set file attributes like ownership
              '';
            };
          }
        );
        default = { };
        example = {
          my-share = {
            source = "/path/to/be/shared";
            target = "/mnt/shared";
          };
        };
        description = ''
          An attributes set of directories that will be shared with the
          virtual machine using VirtFS (9P filesystem over VirtIO).
          The attribute name will be used as the 9P mount tag.
        '';
      };

      mountHostNixStore = mkOption {
        type = types.bool;
        default = !useBootLoader;
        defaultText = literalExpression ''config.virtualisation.qemu.bootMode == "kernel"'';
        description = ''
          Mount the host Nix store as a 9p mount.
        '';
      };

    };
  };

  config = {

    boot.initrd.kernelModules = [
      "virtio_pci" # TODO: platforms without PCI.
      "virtio_blk"
      "virtio_console"
      "virtio_net"
    ] ++ lib.optional (cfg.sharedDirectories != { }) "9pnet_virtio";

    fileSystems = mkMerge (
      [
        (mapAttrs' (tag: share: {
          name = share.target;
          value.device = tag;
          value.fsType = "9p";
          value.neededForBoot = true;
          value.options = [
            "trans=virtio"
            "version=9p2000.L"
          ] ++ lib.optional (tag == "nix-store") "cache=loose";
        }) cfg.sharedDirectories)
      ]
      ++ optional cfg.mountHostNixStore {
        "/nix/store" = {
          device = "/nix/.ro-store";
          fsType = "none";
          options = [ "bind" ];
        };
      }
    );

    virtualisation.qemu.argv =
      (qemuCommand cfg.package)
      ++ bootModeArgs.${cfg.bootMode}
      ++ [
        "-m"
        (toString config.virtualisation.memorySize)
        "-smp"
        (toString config.virtualisation.cores)
      ]
      ++ (flatten (
        mapAttrsToList (tag: share: [
          "-virtfs"
          "local,path=${share.source},mount_tag=${tag},security_model=${share.securityModel},readonly=on"
        ]) cfg.sharedDirectories
      ))
      ++ optionals config.testing.enable [
          "-serial" "mon:stdio"
          "-netdev" "user,id=usernet"
          "-device" "virtio-net-pci,netdev=usernet"
        ]
      ++ cfg.extraArgs;

    virtualisation.qemu.sharedDirectories = {
      nix-store = mkIf cfg.mountHostNixStore {
        source = builtins.storeDir;
        # Always mount this to /nix/.ro-store because we never want to actually
        # write to the host Nix Store.
        target = "/nix/.ro-store";
        securityModel = "none";
      };
    };

  };
}
