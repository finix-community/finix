{ ... }:
{
  config.testing.tests.pmount.pmount = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.pmount.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("pmount setuid wrapper exists"):
          machine.succeed("test -u /run/wrappers/bin/pmount")

      with subtest("/media directory is created"):
          machine.succeed("test -d /media")

      machine.shutdown()
    '';
  };
}
