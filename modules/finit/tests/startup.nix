{ ... }:
{
  config.testing.tests.finit.startup = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    testScript = ''
      machine.start()

      machine.wait_for_console_text("finix - stage 1")
      machine.wait_for_console_text("finix - stage 2")
      machine.wait_for_console_text("entering runlevel S")
      machine.wait_for_console_text("entering runlevel 2")
      machine.wait_for_console_text("getty on /dev/tty1")

      print("system booted to runlevel 2 successfully")

      machine.shutdown()
    '';
  };
}
