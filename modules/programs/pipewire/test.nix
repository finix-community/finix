{ ... }:
{
  config.testing.tests.pipewire.pipewire = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.pipewire.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("pipewire is available"):
          machine.succeed("pw-cli --version")

      machine.shutdown()
    '';
  };
}
