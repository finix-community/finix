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

      with subtest("niri binary is in PATH"):
          machine.succeed("which niri")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/niri.desktop")

      machine.shutdown()
    '';
  };
}
