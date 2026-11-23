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
  mib = 1024 * 1024;

  sectorSize = 512;
  biosBootMiB = 1;
  espMiB = 64;
  biosBootSectors = (biosBootMiB * mib) / sectorSize;
  espSectors = (espMiB * mib) / sectorSize;
  biosBootStart = biosBootSectors;
  espStart = biosBootStart + biosBootSectors;
  rootStart = espStart + espSectors;

  # Space reserved at the end of the disk for the GPT backup header
  gptBackupSectors = 34;

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
        ${lib.getExe' pkgs.coreutils "truncate"} -s ${toString espMiB}M $out
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
        rootSectors=$(((rootBytes + ${toString sectorSize} - 1) / ${toString sectorSize}))
        totalSectors=$(( ${toString rootStart} + rootSectors + ${toString gptBackupSectors} ))

        ${lib.getExe' pkgs.coreutils "truncate"} -s $((totalSectors * ${toString sectorSize})) $out
        ${lib.getExe' pkgs.util-linuxMinimal "sfdisk"} $out <<EOF
        label: gpt
        unit: sectors
        start=${toString biosBootStart}, size=${toString biosBootSectors}, type=21686148-6449-6E6F-744E-656564454649, name=bios-boot
        start=${toString espStart}, size=${toString espSectors}, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP
        start=${toString rootStart}, size=''${rootSectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=finix-root
        EOF
        ${lib.getExe' pkgs.coreutils "dd"} if=${esp} of=$out bs=${toString sectorSize} seek=${toString espStart} conv=notrunc
        ${lib.getExe' pkgs.coreutils "dd"} if=${rootFs} of=$out bs=${toString sectorSize} seek=${toString rootStart} conv=notrunc
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
  imports = [ ../programs/limine ];

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

    programs.limine.enable = true;

    finit.tasks.grow-root-fs = {
      description = "grow the root filesystem to fill the disk";
      runlevel = "S";
      script = ''
        rootLink=$(${lib.getExe' pkgs.coreutils "readlink"} -f /dev/disk/by-label/finix-root)
        part=$(${lib.getExe' pkgs.coreutils "basename"} "$rootLink")
        disk=/dev/$(${lib.getExe' pkgs.coreutils "basename"} "$(${lib.getExe' pkgs.coreutils "readlink"} -f /sys/class/block/$part/..)")
        partNr=$(${lib.getExe' pkgs.coreutils "cat"} /sys/class/block/$part/partition)
        ${lib.getExe' pkgs.cloud-utils "growpart"} "$disk" "$partNr"
        ${lib.getExe' pkgs.e2fsprogs "resize2fs"} "$rootLink"
      '';
    };

    finit.tasks.register-nix-store = {
      description = "register the Nix store and set the system profile";
      runlevel = "S";
      script = ''
        ${lib.getExe' (config.services.nix-daemon.package or pkgs.nix) "nix-store"} \
          --load-db < /nix-path-registration
        ${lib.getExe' (config.services.nix-daemon.package or pkgs.nix) "nix-env"} \
          -p /nix/var/nix/profiles/system --set "$(${lib.getExe' config.programs.coreutils.package "readlink"} -f /run/current-system)"
      '';
    };

    system.build.rawImage = biosRawImage;

    system.build.image = lib.recursiveUpdate biosRawImage {
      passthru.filePath = config.image.filePath;
    };
  };
}
