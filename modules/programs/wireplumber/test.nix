{ ... }:
{
  config.testing.tests.wireplumber.wireplumber = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        programs.pipewire.enable = true;
        programs.wireplumber.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("wireplumber binary is in PATH"):
          machine.succeed("which wireplumber")

      with subtest("wireplumber config fragment is installed"):
          machine.succeed("test -f /etc/wireplumber/wireplumber.conf.d/99-nixos.conf")

      machine.shutdown()
    '';
  };
}
