# test for dhcpcd service
#
# this test verifies that dhcpcd can obtain an ip address from a dhcp
# server (dnsmasq) running on another node.
{
  name = "dhcpcd";

  nodes.server =
    { pkgs, ... }:
    {
      services.mdevd.enable = true;

      # TODO: write a dnsmasq service
      finit.services.dnsmasq = {
        description = "dhcp server";
        command = "${pkgs.dnsmasq}/bin/dnsmasq --no-daemon --dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,1h --interface=eth0 --bind-interfaces --no-resolv --no-hosts";
        conditions = [
          "service/syslogd/running"
          "net/eth0/up"
        ];
      };
    };

  nodes.client =
    { lib, ... }:
    {
      services.mdevd.enable = true;
      services.dhcpcd.enable = true;

      # don't assign a static ip to eth0 - let dhcpcd handle it
      programs.ifupdown-ng.auto = lib.mkForce [ ];
      programs.ifupdown-ng.iface = lib.mkForce { };
    };

  testScript = ''
    start_all()

    server.wait_for_console_text("entering runlevel 2")
    client.wait_for_console_text("entering runlevel 2")

    with subtest("server has static ip"):
        server.wait_until_succeeds("ip addr show eth0 | grep 'inet 192.168.1.2'", timeout=30)

    with subtest("dnsmasq is running"):
        server.wait_until_succeeds("initctl status dnsmasq | grep running", timeout=30)

    with subtest("client obtains dhcp lease"):
        client.wait_until_succeeds("ip addr show eth0 | grep 'inet 192.168.1'", timeout=30)

    with subtest("client can ping server"):
        client.succeed("ping -c 1 192.168.1.2")

    client.shutdown()
    server.shutdown()
  '';
}
