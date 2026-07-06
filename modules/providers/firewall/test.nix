# node ip assignments (sorted alphabetically):
#   client   -> 192.168.1.1
#   iptables -> 192.168.1.2
#   nftables -> 192.168.1.3
{ ... }:
{
  config.testing.tests.firewall.firewall = {
    nodes.client =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        environment.systemPackages = [ pkgs.nmap ];
      };

    nodes.iptables =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;

        providers.firewall.enable = true;
        providers.firewall.backend = "iptables";
        providers.firewall.allowedTCPPorts = [ 8080 ];
        providers.firewall.allowPing = false;
        providers.firewall.rejectPackets = true;

        finit.services.allowed-port = {
          description = "listener on allowed port";
          command = "${pkgs.nmap}/bin/ncat -k -l 8080";
          runlevels = "2345";
        };

        finit.services.blocked-port = {
          description = "listener on blocked port";
          command = "${pkgs.nmap}/bin/ncat -k -l 8081";
          runlevels = "2345";
        };
      };

    nodes.nftables =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;

        providers.firewall.enable = true;
        providers.firewall.allowedTCPPorts = [ 8080 ];

        finit.services.allowed-port = {
          description = "listener on allowed port";
          command = "${pkgs.nmap}/bin/ncat -k -l 8080";
          runlevels = "2345";
        };

        finit.services.blocked-port = {
          description = "listener on blocked port";
          command = "${pkgs.nmap}/bin/ncat -k -l 8081";
          runlevels = "2345";
        };
      };

    testScript = ''
      start_all()

      client.wait_for_console_text("entering runlevel 2")
      iptables.wait_for_console_text("entering runlevel 2")
      nftables.wait_for_console_text("entering runlevel 2")

      client.wait_until_succeeds("initctl cond get net/eth0/running")
      iptables.wait_until_succeeds("initctl status allowed-port | grep running", timeout=30)
      iptables.wait_until_succeeds("initctl status blocked-port | grep running", timeout=30)
      nftables.wait_until_succeeds("initctl status allowed-port | grep running", timeout=30)
      nftables.wait_until_succeeds("initctl status blocked-port | grep running", timeout=30)

      with subtest("nftables: ping is allowed"):
          client.succeed("ping -c 3 192.168.1.3")

      with subtest("nftables: allowed tcp port is reachable"):
          client.succeed("ncat -z -w 3 192.168.1.3 8080")

      with subtest("nftables: blocked tcp port is unreachable"):
          client.fail("ncat -z -w 3 192.168.1.3 8081")

      with subtest("iptables: ping is blocked"):
          client.fail("ping -c 1 -W 3 192.168.1.2")

      with subtest("iptables: allowed tcp port is reachable"):
          client.succeed("ncat -z -w 3 192.168.1.2 8080")

      with subtest("iptables: blocked tcp port is rejected"):
          client.fail("ncat -z -w 3 192.168.1.2 8081")

      client.shutdown()
      iptables.shutdown()
      nftables.shutdown()
    '';
  };
}
