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

      with subtest("nvidia-persistenced is running"):
          machine.wait_until_succeeds("initctl status nvidia-persistenced | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
