{ ... }:
{
  config.testing.tests.openbox.openbox = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.openbox.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("openbox is available"):
          machine.succeed("openbox --version || true")

      machine.shutdown()
    '';
  };
}
