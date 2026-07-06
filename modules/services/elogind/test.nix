{ ... }:
{
  config.testing.tests.elogind.elogind = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.elogind.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("elogind is running"):
          machine.wait_until_succeeds("initctl status elogind | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
