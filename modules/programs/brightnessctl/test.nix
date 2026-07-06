{ ... }:
{
  config.testing.tests.brightnessctl.brightnessctl = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.brightnessctl.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("brightnessctl is available"):
          machine.succeed("brightnessctl --version")

      machine.shutdown()
    '';
  };
}
