{ ... }:
{
  config.testing.tests.ifupdown-ng.ifupdown-ng = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("ifup binary is in PATH"):
          machine.succeed("which ifup")

      with subtest("ifupdown-ng.conf is generated"):
          machine.succeed("test -f /etc/network/ifupdown-ng.conf")

      with subtest("interfaces file is generated"):
          machine.succeed("test -f /etc/network/interfaces")

      machine.shutdown()
    '';
  };
}
