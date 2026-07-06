{ ... }:
{
  config.testing.tests.anacron.anacron = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.anacron.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("anacron binary is available"):
          machine.succeed("anacron -V")

      machine.shutdown()
    '';
  };
}
