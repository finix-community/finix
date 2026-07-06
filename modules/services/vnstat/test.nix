{ ... }:
{
  config.testing.tests.vnstat.vnstat = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.vnstat.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("vnstatd is running"):
          machine.wait_until_succeeds("initctl status vnstat | grep running", timeout=30)

      with subtest("database directory is created"):
          machine.succeed("test -d /var/lib/vnstat")

      with subtest("vnstat configuration is installed"):
          machine.succeed("test -f /etc/vnstat.conf")

      machine.shutdown()
    '';
  };
}
