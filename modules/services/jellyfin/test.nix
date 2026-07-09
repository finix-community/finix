{ ... }:
{
  config.testing.tests.jellyfin.jellyfin = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.jellyfin.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("jellyfin state directory exists"):
          machine.succeed("test -d /var/lib/jellyfin")

      with subtest("jellyfin finit service is configured"):
          machine.succeed("test -f /etc/finit.d/jellyfin.conf")

      machine.shutdown()
    '';
  };
}
