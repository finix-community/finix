{ ... }:
{
  config.testing.tests.ly.ly = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.ly.enable = true;
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("ly is running"):
          machine.wait_until_succeeds("initctl status ly | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
