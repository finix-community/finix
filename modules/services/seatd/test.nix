{ ... }:
{
  config.testing.tests.seatd.seatd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.seatd.enable = true;
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("seatd is running"):
          machine.wait_until_succeeds("initctl status seatd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
