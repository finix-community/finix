{ ... }:
{
  config.testing.tests.acpid.acpid = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.acpid.enable = true;
        services.acpid.handlers.power-button = {
          event = "button/power.*";
          action = ''
            echo "power pressed" > /run/acpid-test
          '';
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("acpid is running"):
          machine.wait_until_succeeds("initctl status acpid | grep running", timeout=30)

      with subtest("event handler config is generated"):
          machine.succeed("test -f /etc/acpi/events/power-button")
          content = machine.succeed("cat /etc/acpi/events/power-button")
          assert "button/power" in content, f"expected event pattern in config, got: {content}"

      machine.shutdown()
    '';
  };
}
