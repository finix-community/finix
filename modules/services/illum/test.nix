{ ... }:
{
  config.testing.tests.illum.illum = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.illum.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("illum is running"):
          machine.wait_until_succeeds("initctl status illum | grep running", timeout=30)

      with subtest("illum finit service is configured"):
          machine.succeed("test -f /etc/finit.d/illum.conf")

      machine.shutdown()
    '';
  };
}
