{ ... }:
{
  config.testing.tests.lemurs.lemurs = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.lemurs.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("lemurs is running"):
          machine.wait_until_succeeds("initctl status lemurs | grep running", timeout=30)

      with subtest("lemurs config is installed"):
          machine.succeed("test -f /etc/lemurs/config.toml")

      machine.shutdown()
    '';
  };
}
