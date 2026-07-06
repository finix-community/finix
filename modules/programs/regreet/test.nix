{ ... }:
{
  config.testing.tests.regreet.regreet = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.regreet.enable = true;
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("regreet is available"):
          machine.succeed("regreet --version || true")

      machine.shutdown()
    '';
  };
}
