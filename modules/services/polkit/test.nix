{ ... }:
{
  config.testing.tests.polkit.polkit = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.polkit.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("dbus is running"):
          machine.wait_until_succeeds("initctl status dbus | grep running", timeout=30)

      with subtest("polkitd is running"):
          machine.wait_until_succeeds("initctl status polkit | grep running", timeout=30)

      with subtest("pkexec setuid wrapper exists"):
          machine.succeed("test -u /run/wrappers/bin/pkexec")

      with subtest("polkit rules are installed"):
          machine.succeed("test -f /etc/polkit-1/rules.d/10-nixos.rules")

      machine.shutdown()
    '';
  };
}
