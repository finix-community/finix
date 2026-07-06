{ ... }:
{
  config.testing.tests.keyd.keyd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.keyd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("keyd is running"):
          machine.wait_until_succeeds("initctl status keyd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
