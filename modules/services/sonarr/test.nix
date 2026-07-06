{ ... }:
{
  config.testing.tests.sonarr.sonarr = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.sonarr.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("sonarr is running"):
          machine.wait_until_succeeds("initctl status sonarr | grep running", timeout=30)

      with subtest("sonarr HTTP API responds"):
          machine.wait_until_succeeds("curl -sf http://localhost:8989/", timeout=60)

      machine.shutdown()
    '';
  };
}
