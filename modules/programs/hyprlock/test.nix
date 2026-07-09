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

      with subtest("hyprlock binary is in PATH"):
          machine.succeed("which hyprlock")

      with subtest("hyprlock PAM service is configured"):
          machine.succeed("test -f /etc/pam.d/hyprlock")

      machine.shutdown()
    '';
  };
}
