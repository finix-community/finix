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

      with subtest("resolvconf binary is in PATH"):
          machine.succeed("which resolvconf")

      with subtest("resolvconf.conf is generated"):
          machine.succeed("test -f /etc/resolvconf.conf")

      machine.shutdown()
    '';
  };
}
