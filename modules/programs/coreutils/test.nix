{ ... }:
{
  config.testing.tests.coreutils.coreutils = {
    nodes.machine = { ... }: { };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("coreutils are available"):
          machine.succeed("ls --version")
          machine.succeed("cp --version")

      machine.shutdown()
    '';
  };
}
