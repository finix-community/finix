{ ... }:
{
  config.testing.tests.dbus.dbus = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.dbus.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("dbus is running"):
          machine.wait_until_succeeds("initctl status dbus | grep running", timeout=30)

      with subtest("dbus system socket exists"):
          machine.succeed("test -S /run/dbus/system_bus_socket")

      machine.shutdown()
    '';
  };
}
