{ ... }:
{
  config.testing.tests.sshguard.sshguard = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.ifupdown-ng.iface.eth0.gateway = "192.168.1.254";
        services.nftables.enable = true;
        services.sshguard.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("sshguard is running"):
          machine.wait_until_succeeds("initctl status sshguard | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
