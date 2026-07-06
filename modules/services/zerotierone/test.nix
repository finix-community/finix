{ ... }:
{
  config.testing.tests.zerotierone.zerotierone = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.zerotierone.enable = true;
        # add a gateway so finit's net/route/default condition fires
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("zerotierone is running"):
          machine.wait_until_succeeds("initctl status zerotierone | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
