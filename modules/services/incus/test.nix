{ ... }:
{
  config.testing.tests.incus.incus = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.incus.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("incus is running"):
          machine.wait_until_succeeds("initctl status incusd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
