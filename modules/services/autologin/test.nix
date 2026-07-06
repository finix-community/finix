{ pkgs, ... }:
{
  config.testing.tests.autologin.autologin = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;
        services.autologin.enable = true;
        services.autologin.user = "testuser";
        services.autologin.command = pkgs.writeShellScript "autologin-cmd" ''
          exec sleep infinity
        '';

        users.users.testuser = {
          uid = 1001;
          group = "testuser";
          home = "/tmp";
        };
        users.groups.testuser = {
          gid = 1001;
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("autologin service starts and holds session open"):
          machine.wait_until_succeeds("initctl status autologin | grep running", timeout=30)

      machine.shutdown()
    '';
  };
}
