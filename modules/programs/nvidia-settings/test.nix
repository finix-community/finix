{ ... }:
{
  config.testing.tests.nvidia-settings.nvidia-settings = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        hardware.nvidia.enable = true;
        programs.nvidia-settings.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nvidia-settings binary is in PATH"):
          machine.succeed("which nvidia-settings")

      machine.shutdown()
    '';
  };
}
