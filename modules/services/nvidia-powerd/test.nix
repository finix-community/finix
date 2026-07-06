{ ... }:
{
  config.testing.tests.nvidia-powerd.nvidia-powerd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        hardware.nvidia.enable = true;
        services.nvidia-powerd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nvidia-powerd finit service is configured"):
          machine.succeed("test -f /etc/finit.d/nvidia-powerd.conf")

      machine.shutdown()
    '';
  };
}
