{ ... }:
{
  config.testing.tests.networkmanager.networkmanager = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.networkmanager.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("networkmanager is running"):
          machine.wait_until_succeeds("initctl status network-manager | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
