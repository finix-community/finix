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
        truncate -s ${toString espMiB}M $out
        mkfs.vfat --invariant -i 12345678 -n ESP $out > /dev/null
        mmd -i $out ::/EFI
        mmd -i $out ::/EFI/BOOT
        mmd -i $out ::/limine
        mcopy -i $out ${limine}/share/limine/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
        mcopy -i $out ${limineConf} ::/limine/limine.conf
        mcopy -i $out ${limine}/share/limine/limine-bios.sys ::/limine/limine-bios.sys
        mcopy -i $out ${kernel} ::/kernel
        mcopy -i $out ${initrd} ::/initrd
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
        img=$out/${config.image.filePath}
        mkdir -p $out

        rootBytes=$(stat -c%s ${rootFs})
        rootSectors=$(((rootBytes + ${toString sectorSize} - 1) / ${toString sectorSize}))
        totalSectors=$(( ${toString rootStart} + rootSectors + ${toString gptBackupSectors} ))

        truncate -s $((totalSectors * ${toString sectorSize})) $img
        sfdisk $img <<EOF
        label: gpt
        unit: sectors
        start=${toString biosBootStart}, size=${toString biosBootSectors}, type=21686148-6449-6E6F-744E-656564454649, name=bios-boot
        start=${toString espStart}, size=${toString espSectors}, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP
        start=${toString rootStart}, size=''${rootSectors}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=finix-root
        EOF
        dd if=${esp} of=$img bs=${toString sectorSize} seek=${toString espStart} conv=notrunc
        dd if=${rootFs} of=$img bs=${toString sectorSize} seek=${toString rootStart} conv=notrunc
      '';

  biosRawImage =
    pkgs.runCommand "finix-bios-${config.image.fileName}"
      {
        nativeBuildInputs = [ limine ];
      }
      ''
        mkdir -p $out
        cp -r ${rawImage}/. $out/
        img=$out/${config.image.filePath}
        chmod u+w $img
        limine bios-install $img 1
      '';

  growRootFs = pkgs.writeShellApplication {
    name = "grow-root-fs";
    runtimeInputs = [
      config.programs.coreutils.package
      pkgs.util-linuxMinimal
      pkgs.e2fsprogs
    ];
    text = ''
      rootLink=$(readlink -f /dev/disk/by-label/finix-root)
      part=$(basename "$rootLink")
      disk=/dev/$(basename "$(readlink -f "/sys/class/block/$part/..")")
      partNr=$(cat "/sys/class/block/$part/partition")

      start=$(cat "/sys/class/block/$part/start")
      size=$(cat "/sys/class/block/$part/size")
      partEnd=$(( (start + size) * 512 ))
      diskBytes=$(blockdev --getsize64 "$disk")
      # Leave room for the backup GPT header and alignment.
      if [ "$partEnd" -lt $((diskBytes - 1048576)) ]; then
        printf ',+\n' | sfdisk -N "$partNr" --no-reread --force "$disk" > /dev/null
        partx -u "$disk"
      fi
      resize2fs "$rootLink"
    '';
  };
in
{
  imports = [ ../programs/limine ];

  config = {
    image.extension = lib.mkDefault "raw";

    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64;
        message = "The raw image is currently x86_64 only (BOOTX64.EFI and limine BIOS).";
      }
      {
        assertion = lib.any (name: config.services.${name}.enable) config.image.deviceManagers;
        message = ''
          The raw image needs a device manager to create /dev/disk/by-label/finix-root and ESP.
          Enable one of: ${
            lib.concatStringsSep ", " (lib.map (name: "services.${name}.enable") config.image.deviceManagers)
          }.
        '';
      }
    ];

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
      command = growRootFs;
    };

    finit.tasks.register-nix-store = {
      description = "register the Nix store and set the system profile";
      runlevel = "S";
      script = ''
        ${lib.getExe' (config.services.nix-daemon.package or pkgs.nix) "nix-store"} \
          --load-db < /nix-path-registration \
          && ${lib.getExe' config.programs.coreutils.package "rm"} -f /nix-path-registration
        ${lib.getExe' (config.services.nix-daemon.package or pkgs.nix) "nix-env"} \
          -p /nix/var/nix/profiles/system --set "$(${lib.getExe' config.programs.coreutils.package "readlink"} -f /run/current-system)"
      '';
    };

    system.build.rawImage = biosRawImage;

    system.build.image = lib.mkDefault (
      lib.recursiveUpdate biosRawImage {
        passthru.filePath = config.image.filePath;
      }
    );
  };
}
