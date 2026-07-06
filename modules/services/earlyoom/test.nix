{ ... }:
{
  config.testing.tests.earlyoom.earlyoom = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.earlyoom.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("earlyoom is running"):
          machine.wait_until_succeeds("initctl status earlyoom | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
