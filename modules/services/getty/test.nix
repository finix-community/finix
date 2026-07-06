{ ... }:
{
  config.testing.tests.getty.getty = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.getty.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("/etc/issue contains finix welcome banner"):
          issue = machine.succeed("cat /etc/issue")
          assert "welcome to finix" in issue, f"expected 'welcome to finix' in /etc/issue, got: {issue}"

      with subtest("getty is running on tty1"):
          machine.wait_until_succeeds("pgrep -fa tty1", timeout=15)

      machine.shutdown()
    '';
  };
}
