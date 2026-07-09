{ ... }:
{
  config.testing.tests.uptime-kuma.uptime-kuma = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.uptime-kuma.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("uptime-kuma is running"):
          machine.wait_until_succeeds("initctl status uptime-kuma | grep running", timeout=30)

      with subtest("uptime-kuma HTTP dashboard responds"):
          machine.wait_until_succeeds("curl -sf http://localhost:3001/", timeout=60)

      machine.shutdown()
    '';
  };
}
