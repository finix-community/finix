{ pkgs, ... }:
{
  config.testing.tests.system76-scheduler.system76-scheduler = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.system76-scheduler.enable = true;
        services.system76-scheduler.configFile = pkgs.writeText "config.kdl" "";
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("system76-scheduler is running"):
          machine.wait_until_succeeds("initctl status system76-scheduler | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
