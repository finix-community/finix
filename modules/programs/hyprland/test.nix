{ ... }:
{
  config.testing.tests.hyprland.hyprland = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.hyprland.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("Hyprland binary is in PATH"):
          machine.succeed("which Hyprland")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/hyprland.desktop")

      machine.shutdown()
    '';
  };
}
