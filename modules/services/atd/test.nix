{ ... }:
{
  config.testing.tests.atd.atd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.atd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("atd is running"):
          machine.wait_until_succeeds("initctl status atd | grep running", timeout=30)

      with subtest("spool directories exist"):
          machine.succeed("test -d /var/spool/atjobs")
          machine.succeed("test -d /var/spool/atspool")

      with subtest("at setuid wrapper exists"):
          machine.succeed("test -u /run/wrappers/bin/at")

      machine.shutdown()
    '';
  };
}
