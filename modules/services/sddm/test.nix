{ ... }:
{
  config.testing.tests.sddm.sddm = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.sddm.enable = true;
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("sddm is running"):
          machine.wait_until_succeeds("initctl status sddm | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
