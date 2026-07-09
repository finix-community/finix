{ ... }:
{
  config.testing.tests.gamemode.gamemode = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.gamemode.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("gamemode is available"):
          machine.succeed("gamemoded --version")

      machine.shutdown()
    '';
  };
}
