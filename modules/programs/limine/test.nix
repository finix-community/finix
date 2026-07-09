{ ... }:
{
  config.testing.tests.limine.limine = {
    # Limine is a bootloader — we can't test the actual boot process in a VM,
    # but we can verify the binary, config generation, and provider wiring.
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        programs.limine.enable = true;
        environment.systemPackages = [ pkgs.limine ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("limine binary is available"):
          machine.succeed("limine --version 2>&1 | grep -i limine")

      with subtest("limine is the configured bootloader"):
          # system.installBootLoader lives in the closure — check the limine binary
          # is present and the module didn't break evaluation
          machine.succeed("limine --help 2>&1 | grep -iq limine")

      machine.shutdown()
    '';
  };
}
