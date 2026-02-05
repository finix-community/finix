# test for multi-vm functionality
#
# this test verifies that multiple vms can be started and communicate
# with each other via the virtual network.
{
  name = "multi-node";

  nodes.client =
    { ... }:
    {
      imports = [ ./lib/common.nix ];
    };

  nodes.server =
    { ... }:
    {
      imports = [ ./lib/common.nix ];
    };

  testScript = ''
    with subtest("start_all starts all nodes"):
        start_all()

    # wait for both VMs to boot
    client.wait_for_console_text("entering runlevel 2")
    server.wait_for_console_text("entering runlevel 2")

    with subtest("nodes have correct ips"):
        client_ip = client.succeed("ip addr show eth0")
        assert "192.168.1.1" in client_ip, f"client missing expected ip 192.168.1.1: {client_ip}"

        server_ip = server.succeed("ip addr show eth0")
        assert "192.168.1.2" in server_ip, f"server missing expected ip 192.168.1.2: {server_ip}"

    with subtest("ping by ip"):
        client.succeed("ping -c 3 192.168.1.2")
        server.succeed("ping -c 3 192.168.1.1")

    with subtest("ping by hostname"):
        client.succeed("ping -c 1 server")
        server.succeed("ping -c 1 client")

    with subtest("shutdown"):
        client.shutdown()
        server.shutdown()
  '';
}
