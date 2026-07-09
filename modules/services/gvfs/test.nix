{ ... }:
{
  config.testing.tests.gvfs.gvfs = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
        services.gvfs.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("gvfs dbus service is registered"):
          machine.succeed("test -f /run/current-system/sw/share/dbus-1/services/org.gtk.vfs.Daemon.service")

      with subtest("GIO_EXTRA_MODULES is set in PAM environment"):
          pam_env = machine.succeed("cat /etc/security/pam_env.conf")
          assert "GIO_EXTRA_MODULES" in pam_env, f"expected GIO_EXTRA_MODULES in pam_env.conf, got: {pam_env}"

      with subtest("dbus is running"):
          machine.wait_until_succeeds("initctl status dbus | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
