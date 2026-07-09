{ ... }:
{
  config.testing.tests.logrotate.logrotate = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.cron.enable = true;
        services.logrotate.enable = true;
        services.logrotate.rules.test = {
          text = ''
            /var/log/test-rotate.log {
              rotate 3
              daily
              missingok
              notifempty
              compress
            }
          '';
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("crond is running"):
          machine.wait_until_succeeds("initctl status cron | grep running", timeout=30)

      with subtest("logrotate entry appears in crontab"):
          crontab = machine.succeed("cat /etc/crontab")
          assert "logrotate" in crontab, f"expected logrotate entry in crontab, got: {crontab}"

      machine.shutdown()
    '';
  };
}
