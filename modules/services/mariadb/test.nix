{ ... }:
{
  config.testing.tests.mariadb.mariadb = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.mariadb.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("mariadb init task completes"):
          machine.wait_until_succeeds("initctl status mariadb-init | grep done", timeout=120)

      with subtest("mariadb is running"):
          machine.wait_until_succeeds("initctl status mariadb | grep running", timeout=60)

      with subtest("mysql cli can query the server"):
          machine.wait_until_succeeds(
              "mysql -u root -e 'SHOW DATABASES;' | grep -q information_schema",
              timeout=30
          )

      machine.shutdown()
    '';
  };
}
