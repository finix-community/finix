{ ... }:
{
  config.testing.tests.users.create = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;

        users.users.alice = {
          isNormalUser = true;
          uid = 1001;
          description = "Alice Test User";
          extraGroups = [
            "wheel"
            "audio"
          ];
        };

        users.users.svcuser = {
          isSystemUser = true;
          uid = 500;
          group = "nogroup";
          description = "Service Account";
        };

        # enable = false: userborn must not create this account
        users.users.ghost = {
          enable = false;
          isSystemUser = true;
          group = "nogroup";
        };

        users.groups.testgroup = {
          gid = 5000;
        };
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("normal user is created"):
          machine.succeed("id alice")

      with subtest("normal user has correct uid"):
          uid = machine.succeed("id -u alice").strip()
          assert uid == "1001", f"expected uid 1001, got '{uid}'"

      with subtest("normal user description is set in /etc/passwd"):
          gecos = machine.succeed("getent passwd alice | cut -d: -f5").strip()
          assert gecos == "Alice Test User", f"expected 'Alice Test User', got '{gecos}'"

      with subtest("normal user home directory is created"):
          machine.succeed("test -d /home/alice")

      with subtest("home directory is owned by the user"):
          owner = machine.succeed("stat -c %U /home/alice").strip()
          assert owner == "alice", f"expected owner 'alice', got '{owner}'"

      with subtest("extraGroups membership is set"):
          machine.succeed("id alice | grep -q wheel")
          machine.succeed("id alice | grep -q audio")

      with subtest("wheel group lists alice as a member"):
          members = machine.succeed("getent group wheel | cut -d: -f4").strip()
          assert "alice" in members, f"expected alice in wheel members, got '{members}'"

      with subtest("system user is created"):
          machine.succeed("id svcuser")
          uid = machine.succeed("id -u svcuser").strip()
          assert uid == "500", f"expected uid 500, got '{uid}'"

      with subtest("disabled user is not created"):
          machine.fail("id ghost")

      with subtest("custom group is created with correct gid"):
          machine.succeed("getent group testgroup")
          gid = machine.succeed("getent group testgroup | cut -d: -f3").strip()
          assert gid == "5000", f"expected gid 5000, got '{gid}'"

      machine.shutdown()
    '';
  };
}
