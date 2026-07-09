{ ... }:
{
  config.testing.tests.regreet.regreet = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        programs.regreet.enable = true;
        environment.systemPackages = [ pkgs.regreet ];
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("regreet binary is in PATH"):
          machine.succeed("which regreet")

      with subtest("greetd is running"):
          machine.wait_until_succeeds("initctl status greetd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
