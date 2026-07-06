{ ... }:
{
  config.testing.tests.php-fpm.php-fpm = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.php-fpm.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("php-fpm is running"):
          machine.wait_until_succeeds("initctl status php-fpm | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
