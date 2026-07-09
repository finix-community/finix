{ ... }:
{
  config.testing.tests.radarr.radarr = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.radarr.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("radarr is running"):
          machine.wait_until_succeeds("initctl status radarr | grep running", timeout=30)

      with subtest("radarr HTTP API responds"):
          machine.wait_until_succeeds("curl -sf http://localhost:7878/", timeout=60)

      machine.shutdown()
    '';
  };
}
