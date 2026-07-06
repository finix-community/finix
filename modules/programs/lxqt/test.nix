{ ... }:
{
  config.testing.tests.lxqt.lxqt = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.lxqt.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("lxqt-session binary is available"):
          machine.succeed("which startlxqt")

      with subtest("pcmanfm-qt file manager is available"):
          machine.succeed("which pcmanfm-qt")

      with subtest("lxqt-panel is available"):
          machine.succeed("which lxqt-panel")

      with subtest("wayland session desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/lxqt-wayland.desktop")

      with subtest("lxqt session.conf is installed"):
          machine.succeed("test -f /etc/xdg/lxqt/session.conf")

      machine.shutdown()
    '';
  };
}
