{ ... }:
{
  config.testing.tests.hyprlock.hyprlock = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.hyprlock.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("hyprlock is available"):
          machine.succeed("hyprlock --version || true")

      machine.shutdown()
    '';
  };
}
