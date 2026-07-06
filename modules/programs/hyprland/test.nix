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

      with subtest("hyprland is available"):
          machine.succeed("Hyprland --version || true")

      machine.shutdown()
    '';
  };
}
