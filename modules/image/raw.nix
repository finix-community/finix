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
        ${lib.getExe' pkgs.mtools "mcopy"} -i $out ${limine}/share/limine/limine-bios.sys ::/limine/limine-bios.sys
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
        # 1 MiB BIOS boot, 64 MiB ESP at sector 4096, then the root filesystem.
        # Leave 34 sectors for the GPT backup at the end.
        totalSectors=$((135168 + rootSectors + 34))

        ${lib.getExe' pkgs.coreutils "truncate"} -s $((totalSectors * 512)) $out
        ${lib.getExe' pkgs.util-linuxMinimal "sfdisk"} $out <<EOF
        label: gpt
        unit: sectors
        start=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649, name=bios-boot
        start=4096, size=131072, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP
        start=135168, size=''${rootSectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=finix-root
        EOF
        ${lib.getExe' pkgs.coreutils "dd"} if=${esp} of=$out bs=512 seek=4096 conv=notrunc
        ${lib.getExe' pkgs.coreutils "dd"} if=${rootFs} of=$out bs=512 seek=135168 conv=notrunc
      '';

  biosRawImage =
    pkgs.runCommand "finix-bios-${config.image.fileName}"
      {
        nativeBuildInputs = [ limine ];
      }
      ''
        cp ${rawImage} $out
        chmod u+w $out
        ${lib.getExe' limine "limine"} bios-install $out 1
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

    system.build.image = lib.recursiveUpdate biosRawImage {
      passthru.filePath = config.image.filePath;
    };
  };
}
