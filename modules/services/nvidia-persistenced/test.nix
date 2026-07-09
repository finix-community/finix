{ ... }:
{
  config.testing.tests.nvidia-persistenced.nvidia-persistenced = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        hardware.nvidia.enable = true;
        services.nvidia-persistenced.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nvidia-persistenced finit service is configured"):
          machine.succeed("test -f /etc/finit.d/nvidia-persistenced.conf")

      machine.shutdown()
    '';
  };
}
