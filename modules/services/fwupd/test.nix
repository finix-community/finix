{ ... }:
{
  config.testing.tests.fwupd.fwupd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.polkit.enable = true;
        services.fwupd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("fwupd is running"):
          machine.wait_until_succeeds("initctl status fwupd | grep running", timeout=60)

      with subtest("fwupd config is installed"):
          machine.succeed("test -f /etc/fwupd/fwupd.conf")

      machine.shutdown()
    '';
  };
}
