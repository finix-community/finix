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

      with subtest("docker daemon config is installed"):
          machine.succeed("test -f /etc/docker/daemon.json")

      with subtest("docker socket exists"):
          machine.wait_until_succeeds("test -S /run/docker.sock", timeout=30)

      machine.shutdown()
    '';
  };
}
