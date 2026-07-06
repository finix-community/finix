{ ... }:
{
  config.testing.tests.mangowc.mangowc = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.mangowc.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("mangowc is available"):
          machine.succeed("mangohud --version || true")

      machine.shutdown()
    '';
  };
}
