{ ... }:
{
  config.testing.tests.accounts-daemon.accounts-daemon = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.accounts-daemon.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("accounts-daemon is running"):
          machine.wait_until_succeeds("initctl status accounts-daemon | grep running", timeout=30)

      with subtest("AccountsService state directory exists"):
          machine.succeed("test -d /var/lib/AccountsService")

      machine.shutdown()
    '';
  };
}
