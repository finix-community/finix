{ ... }:
{
  config.testing.tests.nix-daemon.nix-daemon = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.nix-daemon.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nix-daemon is running"):
          machine.wait_until_succeeds("initctl status nix-daemon | grep running", timeout=60)

      with subtest("daemon socket exists"):
          machine.wait_until_succeeds("test -S /nix/var/nix/daemon-socket/socket", timeout=30)

      with subtest("nix.conf is generated"):
          machine.succeed("test -f /etc/nix/nix.conf")

      with subtest("nix --version works"):
          machine.succeed("nix --version")

      machine.shutdown()
    '';
  };
}
