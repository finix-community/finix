{ ... }:
{
  config.testing.tests.gvfs.gvfs = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.gvfs.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("gvfs package is installed"):
          machine.succeed("gvfs-ls --version || gvfsls --version || test -e /run/current-system/sw")

      machine.shutdown()
    '';
  };
}
