{ ... }:
{
  config.testing.tests.sudo.sudo = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.sudo.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("/etc/sudoers has correct permissions"):
          mode = machine.succeed("stat -c %a /etc/sudoers").strip()
          assert mode == "440", f"expected sudoers mode 440, got {mode}"

      with subtest("sudo setuid wrapper exists"):
          machine.succeed("test -u /run/wrappers/bin/sudo")

      with subtest("sudoers grants wheel group access"):
          sudoers = machine.succeed("cat /etc/sudoers")
          assert "%wheel" in sudoers, f"expected %wheel in sudoers, got: {sudoers}"

      machine.shutdown()
    '';
  };
}
