{
  name = "image-qcow2";

  nodes.machine = { config, ... }: {
    # build the same image the `qcow2` variant produces
    imports = [ ../../modules/image/qcow2.nix ];

    services.getty.enable = true;
    services.mdevd.enable = true;

    virtualisation.qemu.bootMode = "uefi";
    virtualisation.qemu.diskImage = "${config.system.build.image}/${config.image.filePath}";
    virtualisation.qemu.extraArgs = [
      "-drive"
      "file=disk.img,format=qcow2"
    ];
  };

  testScript = ''
    machine.start()

    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")
    machine.wait_for_console_text("getty on /dev/tty1")

    print("qcow2 image booted to runlevel 2 successfully")

    machine.shutdown()
  '';
}
