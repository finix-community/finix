{ ... }:
{
  config.testing.tests.mdevd.mdevd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("mdevd is running"):
          machine.wait_until_succeeds("initctl status mdevd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
