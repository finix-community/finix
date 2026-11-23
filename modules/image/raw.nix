{
  config,
  lib,
  pkgs,
  ...
}:
let
  kernelPackages = config.boot.kernelPackages;
  kernel = "${kernelPackages.kernel}/${
    kernelPackages.kernel.target or kernelPackages.stdenv.hostPlatform.linux-kernel.target
  }";
  initrd = "${config.boot.initrd.package}/initrd";

  inherit (pkgs) limine;

  limineConf = import ./limine-conf.nix {
    inherit lib pkgs;
    kernelTarget = "/kernel";
    initrdTarget = "/initrd";
    topLevel = config.system.topLevel;
    kernelParams = config.boot.kernelParams;
  };

  rootFs = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = [ config.system.topLevel ];
    volumeLabel = "finix-root";
    populateImageCommands = "mkdir -p ./files/boot";
  };

  esp =
    pkgs.runCommand "finix-esp"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.dosfstools
          pkgs.mtools
        ];
      }
      ''
        ${lib.getExe' pkgs.coreutils "truncate"} -s 64M $out
        ${lib.getExe' pkgs.dosfstools "mkfs.vfat"} --invariant -i 12345678 -n ESP $out > /dev/null
        ${lib.getExe' pkgs.mtools "mmd"} -i $out ::/EFI
        ${lib.getExe' pkgs.mtools "mmd"} -i $out ::/EFI/BOOT
        ${lib.getExe' pkgs.mtools "mmd"} -i $out ::/limine
        ${lib.getExe' pkgs.mtools "mcopy"} -i $out ${limine}/share/limine/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
        ${lib.getExe' pkgs.mtools "mcopy"} -i $out ${limineConf} ::/limine/limine.conf
        ${lib.getExe' pkgs.mtools "mcopy"} -i $out ${kernel} ::/kernel
        ${lib.getExe' pkgs.mtools "mcopy"} -i $out ${initrd} ::/initrd
      '';

  rawImage =
    pkgs.runCommand "finix-${config.image.fileName}"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.util-linuxMinimal
        ];
      }
      ''
        rootBytes=$(${lib.getExe' pkgs.coreutils "stat"} -c%s ${rootFs})
        rootSectors=$(((rootBytes + 511) / 512))
        # 1 MiB ESP at sector 2048, 64 MiB long, it should leave the GPT backup at the end
        totalSectors=$((133120 + rootSectors + 34))

        ${lib.getExe' pkgs.coreutils "truncate"} -s $((totalSectors * 512)) $out
        ${lib.getExe' pkgs.util-linuxMinimal "sfdisk"} $out <<EOF
        label: gpt
        unit: sectors
        start=2048, size=131072, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP
        start=133120, size=''${rootSectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=finix-root
        EOF
        ${lib.getExe' pkgs.coreutils "dd"} if=${esp} of=$out bs=512 seek=2048 conv=notrunc
        ${lib.getExe' pkgs.coreutils "dd"} if=${rootFs} of=$out bs=512 seek=133120 conv=notrunc
      '';
in
{
  config = {
    image.extension = "raw";

    fileSystems = lib.mkImageMediaOverride {
      "/" = {
        device = "/dev/disk/by-label/finix-root";
        fsType = "ext4";
        neededForBoot = true;
      };
      "/boot" = {
        device = "/dev/disk/by-label/ESP";
        fsType = "vfat";
      };
    };

    system.build.image = lib.recursiveUpdate rawImage {
      passthru.filePath = config.image.filePath;
    };
  };
}
