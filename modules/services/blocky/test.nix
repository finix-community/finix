{ ... }:
{
  config.testing.tests.blocky.blocky = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.blocky.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("blocky is running"):
          machine.wait_until_succeeds("initctl status blocky | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
