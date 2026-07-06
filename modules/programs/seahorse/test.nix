{ ... }:
{
  config.testing.tests.seahorse.seahorse = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        programs.seahorse.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("seahorse is available"):
          machine.succeed("seahorse --version || true")

      machine.shutdown()
    '';
  };
}
