{
  name = "image-iso";

  nodes.machine = { config, ... }: {
    # build the same image the `iso` variant produces
    imports = [ ../modules/image/iso.nix ];

    services.getty.enable = true;
    services.mdevd.enable = true;

    virtualisation.qemu.bootMode = "uefi";
    virtualisation.qemu.extraArgs = [
      "-drive"
      "file=${config.system.build.image}/${config.image.filePath},media=cdrom,readonly=on"
    ];
  };

  testScript = ''
    machine.start()

    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")
    machine.wait_for_console_text("getty on /dev/tty1")

    print("iso image booted to runlevel 2 successfully")

    machine.shutdown()
  '';
}
