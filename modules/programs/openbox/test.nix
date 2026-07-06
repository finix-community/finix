{ ... }:
{
  config.testing.tests.openbox.openbox = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.openbox.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("openbox binary is in PATH"):
          machine.succeed("which openbox")

      with subtest("xsession desktop file is installed"):
          machine.succeed("test -f /run/current-system/sw/share/xsessions/openbox.desktop")

      machine.shutdown()
    '';
  };
}
