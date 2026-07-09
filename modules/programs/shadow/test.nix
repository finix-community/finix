{ ... }:
{
  config.testing.tests.shadow.shadow = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.shadow.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("shadow setuid wrappers are installed"):
          machine.succeed("test -u /run/wrappers/bin/passwd")
          machine.succeed("test -u /run/wrappers/bin/su")

      machine.shutdown()
    '';
  };
}
