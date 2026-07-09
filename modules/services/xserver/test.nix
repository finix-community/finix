{ ... }:
{
  config.testing.tests.xserver.xserver = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.xorg.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("Xorg binary is available"):
          machine.succeed("Xorg -version 2>&1 | grep -i 'x.org'")

      machine.shutdown()
    '';
  };
}
