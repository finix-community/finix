# comprehensive tests for finit tmpfiles implementation
#
# tests the tmpfiles utility that creates, removes, and manages
# temporary files and directories according to configuration.
{
  name = "tmpfiles";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ./lib/common.nix ];

      # pre-create test tmpfiles.d configs for boot-time testing
      environment.etc."tmpfiles.d/test-boot.conf".text = ''
        d /run/tmpfiles-test/boot-created 0755 root root -
        f /run/tmpfiles-test/boot-created/marker 0644 root root - boot-test-content
      '';

      # test user and group for ownership tests
      users.users.testuser = {
        isSystemUser = true;
        uid = 1234;
        group = "testgroup";
      };

      users.groups.testgroup = {
        gid = 5678;
      };

      # libfaketime for age-based cleanup tests
      environment.systemPackages = [ pkgs.libfaketime ];
    };

  testScript =
    { nodes }:
    let
      tmpfiles = "${nodes.machine.config.finit.package}/libexec/finit/tmpfiles";
    in
    ''
      machine.start()

      # wait for full boot sequence
      machine.wait_for_console_text("finix - stage 1")
      machine.wait_for_console_text("finix - stage 2")
      machine.wait_for_console_text("entering runlevel S")
      machine.wait_for_console_text("entering runlevel 2")

      # boot-time tmpfiles verification

      with subtest("boot-time tmpfiles processing"):
          machine.succeed("test -d /run/tmpfiles-test/boot-created")
          machine.succeed("test -f /run/tmpfiles-test/boot-created/marker")
          content = machine.succeed("cat /run/tmpfiles-test/boot-created/marker")
          assert content.strip() == "boot-test-content", f"boot marker content mismatch: got '{content}'"

      # directory creation tests (d, D types)

      with subtest("d - create directory"):
          machine.succeed("echo 'd /tmp/test-d 0755 root root -' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          machine.succeed("test -d /tmp/test-d")
          mode = machine.succeed("stat -c %a /tmp/test-d")
          assert mode.strip() == "755", f"expected mode 755, got {mode.strip()}"

      with subtest("d - create nested directories"):
          machine.succeed("echo 'd /tmp/test-nested/a/b/c 0755 root root -' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          machine.succeed("test -d /tmp/test-nested/a/b/c")

      with subtest("D - create directory (cleanup variant)"):
          machine.succeed("echo 'D /tmp/test-D 0755 root root -' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          machine.succeed("test -d /tmp/test-D")

      with subtest("D - remove cleans contents but keeps directory"):
          machine.succeed("touch /tmp/test-D/somefile")
          machine.succeed("test -f /tmp/test-D/somefile")
          machine.succeed("${tmpfiles} --remove /tmp/test.conf")
          machine.fail("test -f /tmp/test-D/somefile")
          machine.succeed("test -d /tmp/test-D")

      # file creation tests (f, F types)

      with subtest("f - create file with content"):
          machine.succeed("echo 'f /tmp/test-f-content 0644 root root - hello world' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          content = machine.succeed("cat /tmp/test-f-content")
          assert content.strip() == "hello world", f"expected 'hello world', got '{content.strip()}'"

      with subtest("f - does not overwrite existing file"):
          machine.succeed("echo 'original' > /tmp/test-f-nooverwrite")
          machine.succeed("echo 'f /tmp/test-f-nooverwrite 0644 root root - new content' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          content = machine.succeed("cat /tmp/test-f-nooverwrite")
          assert content.strip() == "original", f"f should not overwrite, got '{content.strip()}'"

      with subtest("F - create/truncate file"):
          machine.succeed("echo 'existing content' > /tmp/test-F")
          machine.succeed("echo 'F /tmp/test-F 0644 root root - new content' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          content = machine.succeed("cat /tmp/test-F")
          assert content.strip() == "new content", f"F should truncate, got '{content.strip()}'"

      # symlink tests (L, L+ types)

      with subtest("L - create symlink"):
          machine.succeed("echo 'L /tmp/test-link - - - - /etc/hostname' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          machine.succeed("test -L /tmp/test-link")
          target = machine.succeed("readlink /tmp/test-link")
          assert target.strip() == "/etc/hostname", f"expected target /etc/hostname, got {target.strip()}"

      with subtest("L+ - force replace symlink"):
          machine.succeed("ln -sf /etc/passwd /tmp/test-link-force")
          machine.succeed("echo 'L+ /tmp/test-link-force - - - - /etc/hostname' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          target = machine.succeed("readlink /tmp/test-link-force")
          assert target.strip() == "/etc/hostname", f"L+ should force replace, got {target.strip()}"

      # remove tests (r, R types)

      with subtest("r - remove single file"):
          machine.succeed("touch /tmp/test-r-file")
          machine.succeed("test -f /tmp/test-r-file")
          machine.succeed("echo 'r /tmp/test-r-file' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --remove /tmp/test.conf")
          machine.fail("test -e /tmp/test-r-file")

      with subtest("R - recursive removal"):
          machine.succeed("mkdir -p /tmp/test-R/a/b/c")
          machine.succeed("touch /tmp/test-R/file1 /tmp/test-R/a/file2")
          machine.succeed("echo 'R /tmp/test-R' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --remove /tmp/test.conf")
          machine.fail("test -e /tmp/test-R")

      # age-based cleanup tests

      with subtest("clean - removes files older than age"):
          machine.succeed("mkdir -p /tmp/test-age")
          machine.succeed("touch /tmp/test-age/old-file")
          machine.succeed("echo 'd /tmp/test-age 0755 root root 1d' > /tmp/test.conf")
          machine.succeed("NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf")
          machine.fail("test -f /tmp/test-age/old-file")

      with subtest("clean - keeps files newer than age"):
          machine.succeed("mkdir -p /tmp/test-age-keep")
          machine.succeed("touch /tmp/test-age-keep/recent-file")
          machine.succeed("echo 'd /tmp/test-age-keep 0755 root root 1d' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --clean /tmp/test.conf")
          machine.succeed("test -f /tmp/test-age-keep/recent-file")

      # ownership tests

      with subtest("d - create directory with specific user:group"):
          machine.succeed("echo 'd /tmp/test-owner-d 0755 testuser testgroup -' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          machine.succeed("test -d /tmp/test-owner-d")
          owner = machine.succeed("stat -c %U:%G /tmp/test-owner-d")
          assert owner.strip() == "testuser:testgroup", f"expected testuser:testgroup, got {owner.strip()}"

      with subtest("ownership - numeric uid:gid"):
          machine.succeed("echo 'd /tmp/test-owner-numeric 0755 1234 5678 -' > /tmp/test.conf")
          machine.succeed("${tmpfiles} --create /tmp/test.conf")
          uid = machine.succeed("stat -c %u /tmp/test-owner-numeric")
          gid = machine.succeed("stat -c %g /tmp/test-owner-numeric")
          assert uid.strip() == "1234" and gid.strip() == "5678", f"expected uid=1234 gid=5678, got uid={uid.strip()} gid={gid.strip()}"

      # error handling

      with subtest("error - requires at least one action flag"):
          machine.succeed("echo 'd /tmp/foo 0755 root root -' > /tmp/test.conf")
          status, _ = machine.execute("${tmpfiles} /tmp/test.conf 2>/dev/null")
          assert status != 0, f"tmpfiles without flags should fail, got status {status}"

      # cleanup and shutdown

      with subtest("shutdown"):
          machine.shutdown()
    '';
}
