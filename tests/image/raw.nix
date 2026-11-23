{
  name = "image-raw";

  nodes.machine = { config, ... }: {
    # build the same image the `raw` variant produces
    imports = [ ../../modules/image/raw.nix ];

    services.getty.enable = true;
    services.mdevd.enable = true;

    virtualisation.qemu.bootMode = "uefi";
    virtualisation.qemu.diskImage = toString config.system.build.image;
    virtualisation.qemu.extraArgs = [
      "-drive"
      "file=disk.img,format=raw"
    ];
  };

  testScript = ''
    machine.start()

    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")
    machine.wait_for_console_text("getty on /dev/tty1")

    print("raw image booted to runlevel 2 successfully")

    machine.shutdown()
  '';
}
