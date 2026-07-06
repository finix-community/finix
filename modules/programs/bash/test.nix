{ ... }:
{
  config.testing.tests.bash.bash = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.bash.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("/etc/bashrc contains PS1 configuration"):
          bashrc = machine.succeed("cat /etc/bashrc")
          assert "PS1=" in bashrc, f"expected PS1 in /etc/bashrc, got: {bashrc}"

      with subtest("bash is listed in /etc/shells"):
          shells = machine.succeed("cat /etc/shells")
          assert "bash" in shells, f"expected bash in /etc/shells, got: {shells}"

      with subtest("bash --version works"):
          machine.succeed("bash --version")

      machine.shutdown()
    '';
  };
}
