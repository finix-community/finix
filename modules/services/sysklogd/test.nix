{ ... }:
{
  config.testing.tests.sysklogd.sysklogd = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.sysklogd.enable = true;
        services.sysklogd.extraConfig = ''
          user.notice    /var/log/test-messages
        '';
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("syslogd is running"):
          machine.wait_until_succeeds("initctl status syslogd | grep running", timeout=30)

      with subtest("extraConfig is written to syslog.d"):
          content = machine.succeed("cat /etc/syslog.d/nixos.conf")
          assert "test-messages" in content, f"expected rule in syslog.d, got: {content}"

      with subtest("logger sends messages to configured file"):
          machine.succeed("logger -p user.notice 'sysklogd-test-message'")
          machine.wait_until_succeeds("grep -q sysklogd-test-message /var/log/test-messages", timeout=15)

      machine.shutdown()
    '';
  };
}
