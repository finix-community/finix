{ ... }:
{
  config.testing.tests.bluetooth.bluetooth = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.bluetooth.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("bluetooth is running"):
          machine.wait_until_succeeds("initctl status bluetooth | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
