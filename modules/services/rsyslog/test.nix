{ lib, ... }:
{
  config.testing.tests.rsyslog.rsyslog = {
    nodes.machine =
      { lib, ... }:
      {
        services.mdevd.enable = true;
        services.sysklogd.enable = lib.mkForce false;
        services.rsyslog.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("rsyslogd is running"):
          machine.wait_until_succeeds("initctl status syslogd | grep running", timeout=30)

      with subtest("logger writes messages to /var/log/syslog"):
          machine.succeed("logger -p user.info 'rsyslog-test-message'")
          machine.wait_until_succeeds("grep -q rsyslog-test-message /var/log/syslog", timeout=15)

      machine.shutdown()
    '';
  };
}
