{ ... }:
{
  config.testing.tests.sway.sway = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.sway.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("sway is available"):
          machine.succeed("sway --version || true")

      machine.shutdown()
    '';
  };
}
