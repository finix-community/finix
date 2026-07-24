# test for the providers.firewall module
#
# verifies that the nftables backend correctly allows and blocks traffic.
#
# node ip assignments (sorted alphabetically):
#   client   -> 192.168.1.1
#   nftables -> 192.168.1.2
{
  name = "firewall";

  nodes.client =
    { pkgs, ... }:
    {
      services.mdevd.enable = true;
      environment.systemPackages = [ pkgs.nmap ];
      finit.runlevel = 3;
    };

  # nftables backend: ping enabled, packets dropped (defaults)
  nodes.nftables =
    { pkgs, ... }:
    {
      services.mdevd.enable = true;
      services.nftables.enable = true;
      finit.runlevel = 3;

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

    client.wait_for_console_text("entering runlevel 3")
    nftables.wait_for_console_text("entering runlevel 3")

    nftables.wait_until_succeeds("initctl status allowed-port | grep running", timeout=30)
    nftables.wait_until_succeeds("initctl status blocked-port | grep running", timeout=30)

    # the firewall rules are applied by a finit task after syslogd is ready,
    # so wait until they are actually loaded before probing
    nftables.wait_until_succeeds("nft list table inet finix-fw", timeout=30)

    with subtest("nftables: ping is allowed"):
        client.succeed("ping -c 3 192.168.1.2")

    with subtest("nftables: allowed tcp port is reachable"):
        client.succeed("ncat -z -w 3 192.168.1.2 8080")

    with subtest("nftables: blocked tcp port is unreachable"):
        client.fail("ncat -z -w 3 192.168.1.2 8081")

    # a task whose runlevels include the current one is re-run by finit right
    # after a manual `initctl stop`, so stop the firewall by leaving its
    # runlevels instead
    with subtest("nftables: stopping the firewall removes the rules"):
        nftables.succeed("initctl runlevel 4")
        nftables.wait_until_fails("nft list table inet finix-fw", timeout=30)
        client.succeed("ncat -z -w 3 192.168.1.2 8081")

    client.shutdown()
    nftables.shutdown()
  '';
}
