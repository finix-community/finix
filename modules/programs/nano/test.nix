{ ... }:
{
  config.testing.tests.nano.nano = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.nano.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nano is installed and runnable"):
          machine.succeed("nano --version")

      machine.shutdown()
    '';
  };
}
