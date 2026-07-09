# node ip assignments (sorted alphabetically):
#   client -> 192.168.1.1
#   server -> 192.168.1.2
{ ... }:
{
  config.testing.tests.networking.multi-node = {
    nodes.client =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    nodes.server =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    testScript = ''
      start_all()

      client.wait_for_console_text("entering runlevel 2")
      server.wait_for_console_text("entering runlevel 2")

      client.wait_until_succeeds("initctl cond get net/eth0/running")
      server.wait_until_succeeds("initctl cond get net/eth0/running")

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

      client.shutdown()
      server.shutdown()
    '';
  };
}
