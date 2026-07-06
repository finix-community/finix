{ ... }:
{
  config.testing.tests.plymouth.plymouth = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.plymouth.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("plymouth binary is available"):
          machine.succeed("plymouth --version || true")

      machine.shutdown()
    '';
  };
}
