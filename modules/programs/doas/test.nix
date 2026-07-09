{ ... }:
{
  config.testing.tests.doas.doas = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;

        programs.doas.enable = true;
        programs.doas.requirePassword = false;

        users.users.alice = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("doas.conf is created"):
          machine.succeed("test -f /etc/doas.conf")

      with subtest("doas.conf has mode 440"):
          mode = machine.succeed("stat -c %a /etc/doas.conf").strip()
          assert mode == "440", f"expected mode 440, got '{mode}'"

      with subtest("doas.conf grants nopass to wheel"):
          machine.succeed("grep -q 'nopass' /etc/doas.conf")
          machine.succeed("grep -q ':wheel' /etc/doas.conf")

      with subtest("doas wrapper exists and is setuid root"):
          machine.succeed("test -u /run/wrappers/bin/doas")

      with subtest("root can run commands via doas (nopass permit root rule)"):
          result = machine.succeed("/run/wrappers/bin/doas id").strip()
          assert "uid=0(root)" in result, f"expected uid=0(root), got '{result}'"

      machine.shutdown()
    '';
  };
}
