{ lib, ... }:
{
  config.testing.tests.virtualbox.virtualbox = {
    nodes.machine =
      { pkgs, lib, ... }:
      {
        services.mdevd.enable = true;
        # virtualbox kernel modules only build on x86_64
        programs.virtualbox.enable = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("system is up"):
          machine.succeed("true")

      machine.shutdown()
    '';
  };
}
