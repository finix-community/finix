{ ... }:
{
  config.testing.tests.udev.udev = {
    nodes.machine =
      { ... }:
      {
        # udev and mdevd are mutually exclusive device managers
        services.udev.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("udevd is running"):
          machine.wait_until_succeeds("initctl status udevd | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
