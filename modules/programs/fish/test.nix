{ ... }:
{
  config.testing.tests.fish.fish = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.fish.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("fish is listed in /etc/shells"):
          shells = machine.succeed("cat /etc/shells")
          assert "fish" in shells, f"expected fish in /etc/shells, got: {shells}"

      with subtest("fish --version works"):
          machine.succeed("fish --version")

      machine.shutdown()
    '';
  };
}
