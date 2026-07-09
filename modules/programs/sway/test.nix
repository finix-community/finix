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

      with subtest("sway binary is in PATH"):
          machine.succeed("which sway")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/sway.desktop")

      machine.shutdown()
    '';
  };
}
