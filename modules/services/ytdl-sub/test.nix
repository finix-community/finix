{ ... }:
{
  config.testing.tests.ytdl-sub.ytdl-sub = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.ytdl-sub.enable = true;
        environment.systemPackages = [ pkgs.ytdl-sub ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("ytdl-sub binary is available"):
          machine.succeed("ytdl-sub --version")

      machine.shutdown()
    '';
  };
}
