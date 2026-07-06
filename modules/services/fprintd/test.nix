{ ... }:
{
  config.testing.tests.fprintd.fprintd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.polkit.enable = true;
        services.fprintd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("fprintd is running"):
          machine.wait_until_succeeds("initctl status fprintd | grep running", timeout=60)

      machine.shutdown()
    '';
  };
}
