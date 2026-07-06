{ ... }:
{
  config.testing.tests.greetd.greetd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.greetd.enable = true;
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("greetd is running"):
          machine.wait_until_succeeds("initctl status greetd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
