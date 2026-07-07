{ ... }:
{
  config.testing.tests.networking.hostname = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;

        networking.hostName = "testnode";
        networking.hosts = {
          "10.1.2.3" = [
            "myserver"
            "myserver.local"
          ];
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("hostname file contains configured name"):
          hostname = machine.succeed("cat /etc/hostname").strip()
          assert hostname == "testnode", f"expected 'testnode', got '{hostname}'"

      with subtest("custom hosts entries are written to /etc/hosts"):
          machine.succeed("grep -q '10.1.2.3' /etc/hosts")
          machine.succeed("grep -q 'myserver' /etc/hosts")
          machine.succeed("grep -q 'myserver.local' /etc/hosts")

      with subtest("configured hostname resolves to 127.0.0.2"):
          result = machine.succeed("getent hosts testnode").strip()
          assert "127.0.0.2" in result, f"expected 127.0.0.2, got '{result}'"

      with subtest("custom host entry resolves"):
          result = machine.succeed("getent hosts myserver").strip()
          assert "10.1.2.3" in result, f"expected 10.1.2.3, got '{result}'"

      with subtest("all aliases for a host resolve"):
          result = machine.succeed("getent hosts myserver.local").strip()
          assert "10.1.2.3" in result, f"expected 10.1.2.3 for alias, got '{result}'"

      with subtest("localhost resolves"):
          result = machine.succeed("getent hosts localhost").strip()
          assert "127.0.0.1" in result, f"expected 127.0.0.1 for localhost, got '{result}'"

      machine.shutdown()
    '';
  };
}
