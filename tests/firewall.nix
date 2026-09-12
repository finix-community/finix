# test for the providers.firewall module
#
# verifies that the nftables backend correctly allows and blocks traffic
#
# node ip assignments (sorted alphabetically):
#   client   -> 192.168.1.1
#   nftables -> 192.168.1.2
{
  name = "firewall";

  nodes.client =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.mdevd.enable = true;

      environment.systemPackages = [ pkgs.nmap ];
    };

  # nftables backend: packets dropped, ping blocked (defaults)
  nodes.nftables =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.mdevd.enable = true;
      services.nftables.enable = true;

      providers.firewall.allowedTCPPorts = [ 8080 ];

      environment.systemPackages = [ pkgs.nmap ];

      finit.tasks.nftables.runlevels = "2";

      finit.services.allowed-port = {
        description = "listener on allowed port";
        command = "${pkgs.nmap}/bin/ncat -k -l 8080";
      };

      finit.services.blocked-port = {
        description = "listener on blocked port";
        command = "${pkgs.nmap}/bin/ncat -k -l 8081";
      };
    };

  testScript = ''
    start_all()

    client.wait_for_console_text("entering runlevel 2")
    nftables.wait_for_console_text("entering runlevel 2")

    nftables.wait_until_succeeds("initctl status allowed-port | grep running", timeout=30)
    nftables.wait_until_succeeds("initctl status blocked-port | grep running", timeout=30)

    # wait until the ruleset is actually loaded before probing
    nftables.wait_until_succeeds("nft list table inet nixos-fw", timeout=30)

    with subtest("nftables: ping is blocked by default"):
        client.fail("ping -c 1 -W 3 192.168.1.2")

    with subtest("nftables: loopback is trusted"):
        nftables.succeed("ncat -z -w 3 127.0.0.1 8081")

    with subtest("nftables: deletions state file is populated"):
        nftables.succeed("grep -q 'delete table inet nixos-fw' /var/lib/nftables/deletions.nft")

    with subtest("nftables: allowed tcp port is reachable"):
        client.succeed("ncat -z -w 3 192.168.1.2 8080")

    with subtest("nftables: blocked tcp port is unreachable"):
        client.fail("ncat -z -w 3 192.168.1.2 8081")

    with subtest("nixos-firewall-tool: detects the nftables backend"):
        nftables.succeed("nixos-firewall-tool show | grep -q 'table inet nixos-fw'")

    with subtest("nixos-firewall-tool: opens a port at runtime"):
        nftables.succeed("nixos-firewall-tool open tcp 8081")
        client.succeed("ncat -z -w 3 192.168.1.2 8081")

    with subtest("nixos-firewall-tool: reset closes the port again"):
        nftables.succeed("nixos-firewall-tool reset")
        client.fail("ncat -z -w 3 192.168.1.2 8081")

    with subtest("nftables: stopping the firewall removes the rules"):
        nftables.succeed("initctl runlevel 3")
        nftables.wait_until_fails("nft list table inet nixos-fw", timeout=30)
        client.succeed("ncat -z -w 3 192.168.1.2 8081")
        nftables.succeed("test ! -s /var/lib/nftables/deletions.nft")

    client.shutdown()
    nftables.shutdown()
  '';
}
