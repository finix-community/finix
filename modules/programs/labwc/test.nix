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

      with subtest("labwc binary is in PATH"):
          machine.succeed("which labwc")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/labwc.desktop")

      machine.shutdown()
    '';
  };
}
