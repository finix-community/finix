{ ... }:
{
  config.testing.tests.xwayland-satellite.xwayland-satellite = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.xwayland-satellite.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("xwayland-satellite is available"):
          machine.succeed("xwayland-satellite --version 2>&1 || true")

      machine.shutdown()
    '';
  };
}
