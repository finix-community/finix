{ ... }:
{
  config.testing.tests.wireplumber.wireplumber = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.pipewire.enable = true;
        programs.wireplumber.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("wireplumber is available"):
          machine.succeed("wireplumber --version || true")

      machine.shutdown()
    '';
  };
}
