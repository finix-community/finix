{ ... }:
{
  config.testing.tests.udisks2.udisks2 = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.udisks2.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")
      with subtest("udisks2 is running"):
          machine.wait_until_succeeds("initctl status udisks2 | grep running", timeout=30)
      machine.shutdown()
    '';
  };
}
