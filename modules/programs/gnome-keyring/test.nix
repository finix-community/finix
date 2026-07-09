{ ... }:
{
  config.testing.tests.gnome-keyring.gnome-keyring = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        programs.gnome-keyring.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("gnome-keyring is available"):
          machine.succeed("gnome-keyring-daemon --version")

      machine.shutdown()
    '';
  };
}
