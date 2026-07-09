# node ip assignments (sorted alphabetically):
#   client -> 192.168.1.1
#   server -> 192.168.1.2
{ ... }:
{
  config.testing.tests.dropbear.dropbear = {
    nodes.client =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    nodes.server =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dropbear.enable = true;
      };

    testScript = ''
      start_all()
      server.wait_for_console_text("entering runlevel 2")

      with subtest("dropbear host key is generated"):
          server.wait_until_succeeds(
              "test -s /var/lib/dropbear/dropbear_ed25519_host_key", timeout=30
          )

      with subtest("dropbear is running"):
          server.wait_until_succeeds("initctl status dropbear | grep -q running", timeout=30)

      with subtest("dropbear is listening on port 22"):
          server.succeed("ss -tlnp | grep -q ':22 '")

      with subtest("client can reach port 22"):
          client.wait_for_console_text("entering runlevel 2")
          client.wait_until_succeeds("nc -z -w 5 192.168.1.2 22", timeout=30)

      server.shutdown()
      client.shutdown()
    '';
  };
}
