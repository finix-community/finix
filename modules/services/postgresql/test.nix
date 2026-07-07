{ ... }:
{
  config.testing.tests.postgresql.postgresql = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.postgresql.enable = true;
        services.postgresql.package = pkgs.postgresql;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("postgresql is running"):
          machine.wait_until_succeeds("initctl status postgresql | grep running", timeout=120)

      with subtest("postgresql accepts connections"):
          machine.wait_until_succeeds("pg_isready -h /run/postgresql", timeout=60)

      machine.shutdown()
    '';
  };
}
