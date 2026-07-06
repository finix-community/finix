{ ... }:
{
  config.testing.tests.limine.limine = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.limine.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("limine is available"):
          machine.succeed("test -e /run/current-system/sw")

      machine.shutdown()
    '';
  };
}
