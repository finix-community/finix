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

  limine = pkgs.limine.override { buildCDs = true; };

  limineConf = import ./limine-conf.nix {
    inherit
      lib
      pkgs
      kernel
      initrd
      ;
    kernelTarget = "/boot/kernel";
    initrdTarget = "/boot/initrd";
    topLevel = config.system.topLevel;
    kernelParams = config.boot.kernelParams;
  };

  deviceManagers = [
    "mdevd"
    "gardendevd"
    "udev"
    "keventd"
  ];

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
        source = "${limine}/share/limine/BOOTX64.EFI";
        target = "/EFI/BOOT/BOOTX64.EFI";
      }
    ];

    squashfsContents = [ config.system.topLevel ];

    efiBootable = true;
    efiBootImage = "boot/limine/limine-uefi-cd.bin";

    bootable = false;
    usbBootable = false;
    syslinux = null;
  };
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
      "/nix/store" = {
        device = "/iso/nix-store.squashfs";
        fsType = "squashfs";
        options = [
          "loop"
        ]
        ++ lib.optional (lib.versionAtLeast kernelPackages.kernel.version "6.2") "threads=multi";
        neededForBoot = true;
      };
    };

    assertions = [
      {
        assertion = lib.any (name: config.services.${name}.enable) deviceManagers;
        message = ''
          The iso image needs a device manager to create /dev/disk/by-label/FINIX_ISO.
          Enable one of: ${
            lib.concatStringsSep ", " (lib.map (name: "services.${name}.enable") deviceManagers)
          }.
        '';
      }
    ];

    # Hybrid ISOs booted from a USB stick need USB storage in the initrd
    boot.initrd.availableKernelModules = [
      "usb_storage"
      "uas"
    ];

    system.build.image = lib.recursiveUpdate iso {
      passthru.filePath = config.image.filePath;
    };
  };
}
