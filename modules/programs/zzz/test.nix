{ ... }:
{
  config.testing.tests.zzz.zzz = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.zzz.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("zzz binary is in PATH"):
          machine.succeed("which zzz")

      machine.shutdown()
    '';
  };
}
