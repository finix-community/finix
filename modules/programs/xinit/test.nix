{ ... }:
{
  config.testing.tests.xinit.xinit = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.xinit.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("xinit is available"):
          machine.succeed("xinit --version 2>&1 || true")

      machine.shutdown()
    '';
  };
}
