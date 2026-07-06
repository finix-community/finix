{ ... }:
{
  config.testing.tests.openresolv.openresolv = {
    nodes.machine = { ... }: { };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("system is up"):
          machine.succeed("true")

      machine.shutdown()
    '';
  };
}
