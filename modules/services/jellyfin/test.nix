{ ... }:
{
  config.testing.tests.jellyfin.jellyfin = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.jellyfin.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("jellyfin is running"):
          machine.wait_until_succeeds("initctl status jellyfin | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
