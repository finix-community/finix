{
  name = "image-iso";

  nodes =
    let
      isoNode =
        bootMode:
        { config, ... }:
        {
          # build the same image the `iso` variant produces
          imports = [ ../modules/image/iso.nix ];

          services.getty.enable = true;
          services.mdevd.enable = true;

          virtualisation.qemu.bootMode = bootMode;
          virtualisation.qemu.extraArgs = [
            "-drive"
            "file=${config.system.build.image}/${config.image.filePath},media=cdrom,readonly=on"
          ];
        };
    in
    {
      uefi = isoNode "uefi";
      bios = isoNode "bios";
    };

  testScript = ''
    with subtest("uefi"):
      uefi.start()

      uefi.wait_for_console_text("finix - stage 1")
      uefi.wait_for_console_text("finix - stage 2")
      uefi.wait_for_console_text("entering runlevel S")
      uefi.wait_for_console_text("entering runlevel 2")
      uefi.wait_for_console_text("getty on /dev/tty1")

      uefi.succeed("touch /nix/store/.rw-check")
      print("iso image booted to runlevel 2 successfully")

      uefi.shutdown()

    with subtest("bios"):
      bios.start()

      bios.wait_for_console_text("finix - stage 1")
      bios.wait_for_console_text("finix - stage 2")
      bios.wait_for_console_text("entering runlevel S")
      bios.wait_for_console_text("entering runlevel 2")
      bios.wait_for_console_text("getty on /dev/tty1")

      bios.succeed("touch /nix/store/.rw-check")
      print("iso image booted to runlevel 2 successfully")

      bios.shutdown()
  '';
}
