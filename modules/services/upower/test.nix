{ ... }:
{
  config.testing.tests.upower.upower = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.upower.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("upower is running"):
          machine.wait_until_succeeds("initctl status upower | grep running", timeout=30)

      with subtest("upower can enumerate devices"):
          machine.succeed("upower --enumerate")

      machine.shutdown()
    '';
  };
}
