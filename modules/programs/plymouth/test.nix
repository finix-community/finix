{ ... }:
{
  config.testing.tests.plymouth.plymouth = {
    # Plymouth is an initrd-only splash screen module — the binary and config
    # live in the initrd, not the running system.  The only runtime effect is
    # the "splash" kernel parameter being present on the cmdline.
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.plymouth.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("splash kernel parameter is set"):
          machine.succeed("grep -q splash /proc/cmdline")

      machine.shutdown()
    '';
  };
}
