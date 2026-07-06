# node ip assignments (sorted alphabetically):
#   client -> 192.168.1.1
#   server -> 192.168.1.2
{ ... }:
{
  config.testing.tests.openssh.openssh = {
    nodes.client =
      { ... }:
      {
        services.mdevd.enable = true;
      };

    nodes.server =
      { ... }:
      {
        services.mdevd.enable = true;
        services.openssh.enable = true;
        services.openssh.settings.PermitRootLogin = "yes";
        services.openssh.settings.PasswordAuthentication = false;
      };

    testScript = ''
      start_all()
      server.wait_for_console_text("entering runlevel 2")

      with subtest("ssh host key is generated"):
          server.wait_until_succeeds("test -s /var/lib/sshd/ssh_host_ed25519_key", timeout=30)

      with subtest("sshd is running"):
          server.wait_until_succeeds("initctl status sshd | grep -q running", timeout=30)

      with subtest("sshd is listening on port 22"):
          server.succeed("ss -tlnp | grep -q ':22 '")

      with subtest("sshd_config has correct settings"):
          server.succeed("grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config")
          server.succeed("grep -q 'PermitRootLogin yes' /etc/ssh/sshd_config")

      with subtest("client can reach port 22"):
          client.wait_for_console_text("entering runlevel 2")
          client.wait_until_succeeds("nc -z -w 5 192.168.1.2 22", timeout=30)

      server.shutdown()
      client.shutdown()
    '';
  };
}
