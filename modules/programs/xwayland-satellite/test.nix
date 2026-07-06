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

      with subtest("xwayland-satellite binary is in PATH"):
          machine.succeed("which xwayland-satellite")

      with subtest("X11 socket directory is created by tmpfiles"):
          machine.succeed("test -d /tmp/.X11-unix")

      machine.shutdown()
    '';
  };
}
