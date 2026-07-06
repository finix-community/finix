{ ... }:
{
  config.testing.tests.fcron.fcron = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.fcron.enable = true;
        services.fcron.systab = [
          "@hourly root echo fcron-test-entry"
        ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("fcrontab task completes"):
          machine.wait_until_succeeds("initctl status fcrontab | grep done", timeout=60)

      with subtest("fcron is running"):
          machine.wait_until_succeeds("initctl status fcron | grep running", timeout=30)

      with subtest("fcron.conf is installed"):
          machine.succeed("test -f /etc/fcron.conf")

      with subtest("fcron.allow is installed"):
          content = machine.succeed("cat /etc/fcron.allow")
          assert "all" in content, f"expected 'all' in fcron.allow, got: {content}"

      with subtest("fcron spool directory exists"):
          machine.succeed("test -d /var/spool/fcron")

      machine.shutdown()
    '';
  };
}
