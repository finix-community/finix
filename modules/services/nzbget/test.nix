{ ... }:
{
  config.testing.tests.nzbget.nzbget = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.nzbget.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nzbget is running"):
          machine.wait_until_succeeds("initctl status nzbget | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
