{ ... }:
{
  config.testing.tests.tzupdate.tzupdate = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.tzupdate.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("tzupdate task ran"):
          machine.wait_until_succeeds("initctl status tzupdate", timeout=30)

      machine.shutdown()
    '';
  };
}
