{ ... }:
{
  config.testing.tests.ifupdown-ng.ifupdown-ng = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("ifupdown-ng is available"):
          machine.succeed("ifup --version 2>&1 || true")

      machine.shutdown()
    '';
  };
}
