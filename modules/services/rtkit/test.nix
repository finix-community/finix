{ ... }:
{
  config.testing.tests.rtkit.rtkit = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.polkit.enable = true;
        services.rtkit.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("rtkit-daemon is running"):
          machine.wait_until_succeeds("initctl status rtkit-daemon | grep running", timeout=60)

      with subtest("rtkit user exists"):
          machine.succeed("id rtkit")

      machine.shutdown()
    '';
  };
}
