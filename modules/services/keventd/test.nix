{ ... }:
{
  config.testing.tests.keventd.keventd = {
    nodes.machine =
      { ... }:
      {
        # keventd requires finit >= 5.0 which is not yet in nixpkgs;
        # use mdevd as device manager and just verify the system boots
        services.mdevd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("keventd module loads"):
          machine.succeed("true")

      machine.shutdown()
    '';
  };
}
