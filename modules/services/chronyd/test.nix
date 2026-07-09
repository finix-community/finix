{ ... }:
{
  config.testing.tests.chronyd.chronyd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.chrony.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("chronyd is running"):
          machine.wait_until_succeeds("initctl status chronyd | grep running", timeout=30)

      with subtest("chrony drift file is initialised"):
          machine.succeed("test -f /var/lib/chrony/chrony.drift")

      machine.shutdown()
    '';
  };
}
