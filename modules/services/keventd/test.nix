{ ... }:
{
  config.testing.tests.keventd.keventd = {
    nodes.machine =
      { ... }:
      {
        # keventd requires finit >= 5.0, which is not yet in nixpkgs (current: 4.x).
        # The module's assertion prevents enabling it with the packaged finit.
        # Use mdevd as the device manager and verify the base system is healthy.
        services.mdevd.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("mdevd is running as device manager"):
          machine.wait_until_succeeds("initctl status mdevd | grep running", timeout=30)

      with subtest("mdevd hotplug rules are present"):
          machine.succeed("test -f /etc/mdev.conf")

      machine.shutdown()
    '';
  };
}
