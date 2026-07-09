{ ... }:
{
  config.testing.tests.cron.cron = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.cron.enable = true;
        services.cron.systab = [
          "*/5 * * * * root echo cron-test-entry"
        ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("crond is running"):
          machine.wait_until_succeeds("initctl status cron | grep running", timeout=30)

      with subtest("/etc/crontab has expected content"):
          crontab = machine.succeed("cat /etc/crontab")
          assert "SHELL=" in crontab, f"expected SHELL= in crontab, got: {crontab}"
          assert "cron-test-entry" in crontab, f"expected custom entry in crontab, got: {crontab}"

      with subtest("crontab setuid wrapper exists"):
          machine.succeed("test -u /run/wrappers/bin/crontab")

      machine.shutdown()
    '';
  };
}
