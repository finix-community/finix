{ ... }:
{
  config.testing.tests.lxqt.lxqt = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.lxqt.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("lxqt is available"):
          machine.succeed("test -e /run/current-system/sw")

      machine.shutdown()
    '';
  };
}
