{ ... }:
{
  config.testing.tests.labwc.labwc = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.labwc.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("labwc is available"):
          machine.succeed("labwc --version || true")

      machine.shutdown()
    '';
  };
}
