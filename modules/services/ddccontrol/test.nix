{ ... }:
{
  config.testing.tests.ddccontrol.ddccontrol = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.ddccontrol.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("ddccontrol is running"):
          machine.wait_until_succeeds("initctl status ddccontrol | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
