{ pkgs, lib, ... }:
{
  config.testing.tests.thermald.thermald = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.thermald.enable = true;
        # thermald is x86-only; provide a stub on other platforms
        services.thermald.package = if pkgs.stdenv.hostPlatform.isx86_64 then pkgs.thermald
          else pkgs.writeShellScriptBin "thermald" "exec true";
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("thermald is running"):
          machine.wait_until_succeeds("initctl status thermald | grep running", timeout=30)

      with subtest("thermald finit service is configured"):
          machine.succeed("test -f /etc/finit.d/thermald.conf")

      machine.shutdown()
    '';
  };
}
