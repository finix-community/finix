{ ... }:
{
  config.testing.tests.boot.sysctl = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;

        boot.kernel.sysctl = {
          "vm.swappiness" = 42;
          "net.ipv4.ip_forward" = 1;
          "vm.dirty_ratio" = null;
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("sysctl config file is generated"):
          machine.succeed("test -f /etc/sysctl.d/60-finix.conf")

      with subtest("configured values appear in the config file"):
          machine.succeed("grep -q 'vm.swappiness=42' /etc/sysctl.d/60-finix.conf")
          machine.succeed("grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.d/60-finix.conf")

      with subtest("null values are excluded from the config file"):
          machine.fail("grep -q 'vm.dirty_ratio' /etc/sysctl.d/60-finix.conf")

      with subtest("vm.swappiness is applied at boot"):
          val = machine.succeed("cat /proc/sys/vm/swappiness").strip()
          assert val == "42", f"expected vm.swappiness=42, got '{val}'"

      with subtest("net.ipv4.ip_forward is applied at boot"):
          val = machine.succeed("cat /proc/sys/net/ipv4/ip_forward").strip()
          assert val == "1", f"expected ip_forward=1, got '{val}'"

      with subtest("default kptr_restrict is applied"):
          val = machine.succeed("cat /proc/sys/kernel/kptr_restrict").strip()
          assert val == "1", f"expected kptr_restrict=1, got '{val}'"

      machine.shutdown()
    '';
  };
}
