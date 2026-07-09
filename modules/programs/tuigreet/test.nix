{ ... }:
{
  config.testing.tests.tuigreet.tuigreet = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        programs.tuigreet.enable = true;
        environment.systemPackages = [ pkgs.tuigreet ];
        finit.runlevel = 3;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 3")

      with subtest("tuigreet is available"):
          machine.succeed("tuigreet --version")

      machine.shutdown()
    '';
  };
}
