{ ... }:
{
  config.testing.tests.micro.micro = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.micro.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("micro is installed and runnable"):
          machine.succeed("micro --version")

      machine.shutdown()
    '';
  };
}
