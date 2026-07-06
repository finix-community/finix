{ lib, ... }:
{
  config.testing.tests.virtualbox.virtualbox = {
    nodes.machine =
      { pkgs, lib, ... }:
      {
        services.mdevd.enable = true;
        # virtualbox only builds on x86_64
        programs.virtualbox.enable = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      arch = machine.succeed("uname -m").strip()

      if arch == "x86_64":
          with subtest("VBoxManage is available"):
              machine.succeed("VBoxManage --version")

          with subtest("vboxusers group exists"):
              machine.succeed("getent group vboxusers")

          with subtest("VBoxHeadless is available"):
              machine.succeed("VBoxHeadless --version")
      else:
          with subtest("non-x86 platform skips virtualbox"):
              machine.log(f"virtualbox is x86-only; skipping on {arch}")

      machine.shutdown()
    '';
  };
}
