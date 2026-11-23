{
  name = "image-raw";

  nodes =
    let
      rawNode =
        bootMode:
        { config, lib, ... }:
        {
          # build the same image the `raw` variant produces
          imports = [ ../../modules/image/raw.nix ];

          services.getty.enable = true;
          services.mdevd.enable = true;

          virtualisation.qemu.bootMode = bootMode;
          virtualisation.qemu.diskImage = toString config.system.build.image;
          virtualisation.qemu.extraArgs = [
            "-drive"
            "file=disk.img,format=raw"
          ]
          ++ lib.optionals (bootMode == "bios") [
            "-boot"
            "order=c"
          ];
        };
    in
    {
      uefi = rawNode "uefi";
      bios = rawNode "bios";
    };

  testScript = ''
    with subtest("uefi"):
      uefi.start()

      uefi.wait_for_console_text("finix - stage 1")
      uefi.wait_for_console_text("finix - stage 2")
      uefi.wait_for_console_text("entering runlevel S")
      uefi.wait_for_console_text("entering runlevel 2")
      uefi.wait_for_console_text("getty on /dev/tty1")

      uefi.succeed("/run/current-system/bin/switch-to-configuration boot")
      uefi.succeed("test $(df -k / | tail -1 | tr -s ' ' | cut -d' ' -f2) -gt 1000000")
      print("raw image booted to runlevel 2 successfully")

      uefi.shutdown()

    with subtest("bios"):
      bios.start()

      bios.wait_for_console_text("finix - stage 1")
      bios.wait_for_console_text("finix - stage 2")
      bios.wait_for_console_text("entering runlevel S")
      bios.wait_for_console_text("entering runlevel 2")
      bios.wait_for_console_text("getty on /dev/tty1")

      bios.succeed("/run/current-system/bin/switch-to-configuration boot")
      bios.succeed("test $(df -k / | tail -1 | tr -s ' ' | cut -d' ' -f2) -gt 1000000")
      print("raw image booted to runlevel 2 successfully")

      bios.shutdown()
  '';
}
