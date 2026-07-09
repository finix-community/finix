{ ... }:
{
  config.testing.tests.mangowc.mangowc = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.mangowc.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("mango binary is in PATH"):
          machine.succeed("which mango")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/mango.desktop")

      machine.shutdown()
    '';
  };
}
