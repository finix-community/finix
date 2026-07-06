{ ... }:
{
  config.testing.tests.zfs.zfs = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.zfs.autoScrub.enable = true;
        boot.supportedFilesystems.zfs.enable = true;
        environment.systemPackages = [ pkgs.zfs ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("create zpool on file"):
          machine.succeed("dd if=/dev/zero of=/tmp/zfs.img bs=1M count=256")
          machine.succeed("zpool create testpool /tmp/zfs.img")

      with subtest("zpool scrub runs"):
          machine.succeed("zpool scrub testpool")
          machine.wait_until_succeeds("zpool status testpool | grep -E 'scrub repaired|scan: scrub'", timeout=30)

      machine.shutdown()
    '';
  };
}
