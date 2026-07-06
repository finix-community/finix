{ ... }:
{
  config.testing.tests.flatpak.flatpak = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.flatpak.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("flatpak binary is available"):
          machine.succeed("flatpak --version")

      with subtest("flatpak user and group exist"):
          machine.succeed("id flatpak")
          machine.succeed("getent group flatpak")

      machine.shutdown()
    '';
  };
}
