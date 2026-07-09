{ ... }:
{
  config.testing.tests.fstrim.fstrim = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.fstrim.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("fstrim binary is available"):
          machine.succeed("fstrim --version")

      machine.shutdown()
    '';
  };
}
