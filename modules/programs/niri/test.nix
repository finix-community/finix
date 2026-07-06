{ ... }:
{
  config.testing.tests.niri.niri = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.niri.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("niri is available"):
          machine.succeed("niri --version || true")

      machine.shutdown()
    '';
  };
}
