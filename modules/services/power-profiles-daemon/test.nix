{ ... }:
{
  config.testing.tests.power-profiles-daemon.power-profiles-daemon = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.power-profiles-daemon.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("power-profiles-daemon is running"):
          machine.wait_until_succeeds("initctl status power-profiles-daemon | grep running", timeout=60)

      with subtest("powerprofilesctl can list profiles"):
          machine.succeed("powerprofilesctl list")

      machine.shutdown()
    '';
  };
}
