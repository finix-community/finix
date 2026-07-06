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

      with subtest("nvidia-powerd is running"):
          machine.wait_until_succeeds("initctl status nvidia-powerd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
