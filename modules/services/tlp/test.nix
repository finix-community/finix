{ ... }:
{
  config.testing.tests.tlp.tlp = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.tlp.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("tlp binary is available"):
          machine.succeed("tlp --version")

      machine.shutdown()
    '';
  };
}
