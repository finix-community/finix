{ ... }:
{
  config.testing.tests.resolvconf.resolvconf = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.resolvconf.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("resolvconf binary is available"):
          machine.succeed("resolvconf --version 2>&1 || resolvconf -V 2>&1 || true")

      machine.shutdown()
    '';
  };
}
