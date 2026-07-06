{ ... }:
{
  config.testing.tests.iwd.iwd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.iwd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("iwd is running"):
          machine.wait_until_succeeds("initctl status iwd | grep running", timeout=30)

      with subtest("iwd config is installed"):
          machine.succeed("test -f /etc/iwd/main.conf")

      machine.shutdown()
    '';
  };
}
