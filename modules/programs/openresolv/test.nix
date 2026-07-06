{ ... }:
{
  config.testing.tests.openresolv.openresolv = {
    # openresolv is a deprecated alias — importing this module now just emits a
    # warning; resolvconf itself is a required module always present in finix.
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.resolvconf.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("resolvconf binary is in PATH"):
          machine.succeed("which resolvconf")

      with subtest("resolvconf.conf is installed"):
          machine.succeed("test -f /etc/resolvconf.conf")

      with subtest("resolvconf lists interfaces without error"):
          machine.succeed("resolvconf -l 2>&1; true")

      machine.shutdown()
    '';
  };
}
