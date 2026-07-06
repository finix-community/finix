{ ... }:
{
  config.testing.tests.docker.docker = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.docker.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("docker is running"):
          machine.wait_until_succeeds("initctl status docker | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
