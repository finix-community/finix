{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  kernelPackages = config.boot.kernelPackages;
  kernel = "${kernelPackages.kernel}/${
    kernelPackages.kernel.target or kernelPackages.stdenv.hostPlatform.linux-kernel.target
  }";
  initrd = "${config.boot.initrd.package}/initrd";

  limine = pkgs.limine.override { buildCDs = true; };

  # make-iso9660-image.sh unconditionally sorts /isolinux to the start of the media when bootable = true and aborts if the directory is missing
  isolinuxPlaceholder = pkgs.runCommand "isolinux" { } ''
    mkdir -p $out
  '';

  limineConf = import ./limine-conf.nix {
    inherit lib pkgs;
    kernelTarget = "/boot/kernel";
    initrdTarget = "/boot/initrd";
    topLevel = config.system.topLevel;
    kernelParams = config.boot.kernelParams;
  };

  iso = pkgs.callPackage (pkgs.path + "/nixos/lib/make-iso9660-image.nix") {
    isoName = config.image.fileName;
    volumeID = "FINIX_ISO";

    contents = [
      {
        source = kernel;
        target = "/boot/kernel";
      }
      {
        source = initrd;
        target = "/boot/initrd";
      }
      {
        source = limineConf;
        target = "/boot/limine/limine.conf";
      }
      {
        source = "${limine}/share/limine/limine-uefi-cd.bin";
        target = "/boot/limine/limine-uefi-cd.bin";
      }
      {
        source = "${limine}/share/limine/limine-bios-cd.bin";
        target = "/boot/limine/limine-bios-cd.bin";
      }
      {
        source = "${limine}/share/limine/limine-bios.sys";
        target = "/boot/limine/limine-bios.sys";
      }
      {
        source = isolinuxPlaceholder;
        target = "/isolinux";
      }
      {
        source = "${limine}/share/limine/BOOTX64.EFI";
        target = "/EFI/BOOT/BOOTX64.EFI";
      }
    ];

    squashfsContents = [ config.system.topLevel ];

    efiBootable = true;
    efiBootImage = "boot/limine/limine-uefi-cd.bin";

    bootable = true;
    bootImage = "/boot/limine/limine-bios-cd.bin";
    usbBootable = false;
    syslinux = null;
  };

  # The El Torito entry alone is not enough, limine's BIOS stage 1 has to be written into the image.
  # The protective GPT left by -isohybrid-gpt-basdat makes limine refuse without --force.
  biosIso =
    pkgs.runCommand "finix-bios-${config.image.fileName}"
      {
        nativeBuildInputs = [ limine ];
      }
      ''
        mkdir -p $out/iso
        cp ${iso}/${config.image.filePath} $out/iso/${config.image.fileName}
        chmod u+w $out/iso/${config.image.fileName}
        ${lib.getExe' limine "limine"} bios-install $out/iso/${config.image.fileName} --force
      '';
in
{
  config = {
    image.extension = "iso";
    image.filePath = "iso/${config.image.fileName}";

    fileSystems = lib.mkImageMediaOverride {
      "/" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };
      "/iso" = {
        device = "/dev/disk/by-label/FINIX_ISO";
        fsType = "iso9660";
        neededForBoot = true;
        noCheck = true;
      };
      "/nix/.ro-store" = {
        device = "/iso/nix-store.squashfs";
        fsType = "squashfs";
        options = [
          "loop"
        ]
        ++ lib.optional (lib.versionAtLeast kernelPackages.kernel.version "6.2") "threads=multi";
        neededForBoot = true;
      };
      "/nix/.rw-store" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };
      "/nix/store" = {
        device = "overlay";
        fsType = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store"
        ];
        neededForBoot = true;
      };
    };

    boot.initrd.finit.tasks.prepare-overlay-store = {
      conditions = [ "task/mount-${utils.escapePath "/nix/.rw-store"}/success" ];
      script = ''
        mkdir -p /sysroot/nix/.rw-store/store /sysroot/nix/.rw-store/work
      '';
    };

    boot.initrd.finit.tasks."mount-${utils.escapePath "/nix/store"}".conditions = lib.mkAfter [
      "task/prepare-overlay-store/success"
    ];

    # An overlay is already writable with the overlay
    finit.tasks.remount-nix-store.enable = false;

    # Hybrid ISOs booted from a USB stick need USB storage in the initrd
    boot.initrd.availableKernelModules = [
      "usb_storage"
      "uas"
    ];

    finit.tasks.register-nix-store = {
      description = "register the Nix store from the iso image";
      runlevel = "S";
      script = ''
        ${lib.getExe' (config.services.nix-daemon.package or pkgs.nix) "nix-store"} \
          --load-db < /nix/store/nix-path-registration
      '';
    };

    finit.services.nix-daemon.conditions = [ "task/register-nix-store/success" ];

    system.build.image = lib.recursiveUpdate biosIso {
      passthru.filePath = config.image.filePath;
    };
  };
}
