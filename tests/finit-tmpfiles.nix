# comprehensive tests for finit tmpfiles implementation
{
  testenv ? import ./testenv { },
}:

testenv.mkTest {
  name = "finit-tmpfiles";

  nodes.machine =
    { pkgs, ... }:
    {
      finit.runlevel = 2;
      services.mdevd.enable = true;

      finit.package = pkgs.finit.overrideAttrs (finalAttrs: {
        version = "4.16";

        src = pkgs.fetchFromGitHub {
          owner = "aanderse";
          repo = "finit";
          rev = "1092c0067e64c7322fa1148d88d565452c5e5f88";
          sha256 = "sha256-VymxK4TIFnJR3rVga3gCpbnpdMsNkPM6T62FMY45gIc=";
        };
      });

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

      # libfaketime for age-based cleanup tests - run tmpfiles in the "future" with NO_FAKE_STAT=1 so files appear old
      environment.systemPackages = [ pkgs.libfaketime ];
    };

  testScript =
    { nodes }:
    let
      tmpfiles = "${nodes.machine.config.finit.package}/libexec/finit/tmpfiles";
    in
    ''
      machine start
      machine expect "entering runlevel 2"
      after 1000

      # boot-time tmpfiles verification

      subtest "boot-time tmpfiles processing" {
        machine succeed "test -d /run/tmpfiles-test/boot-created"
        machine succeed "test -f /run/tmpfiles-test/boot-created/marker"
        set content [machine succeed "cat /run/tmpfiles-test/boot-created/marker"]
        if {[string trim $content] ne "boot-test-content"} {
          error "boot marker content mismatch: got '$content'"
        }
      }

      # directory creation tests (d, D types)

      subtest "d - create directory" {
        machine succeed "echo 'd /tmp/test-d 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -d /tmp/test-d"
        set mode [machine succeed "stat -c %a /tmp/test-d"]
        if {[string trim $mode] ne "755"} {
          error "expected mode 755, got [string trim $mode]"
        }
      }

      subtest "d - create nested directories" {
        machine succeed "echo 'd /tmp/test-nested/a/b/c 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -d /tmp/test-nested/a/b/c"
      }

      subtest "d - directory with mode 0700" {
        machine succeed "echo 'd /tmp/test-private 0700 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set mode [machine succeed "stat -c %a /tmp/test-private"]
        if {[string trim $mode] ne "700"} {
          error "expected mode 700, got [string trim $mode]"
        }
      }

      subtest "D - create directory (cleanup variant)" {
        machine succeed "echo 'D /tmp/test-D 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -d /tmp/test-D"
      }

      subtest "D - remove cleans contents but keeps directory" {
        machine succeed "touch /tmp/test-D/somefile"
        machine succeed "test -f /tmp/test-D/somefile"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -f /tmp/test-D/somefile"
        machine succeed "test -d /tmp/test-D"
      }

      # file creation tests (f, F types)

      subtest "f - create empty file" {
        machine succeed "echo 'f /tmp/test-f-empty 0644 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -f /tmp/test-f-empty"
        set size [machine succeed "stat -c %s /tmp/test-f-empty"]
        if {[string trim $size] ne "0"} {
          error "expected empty file, got size [string trim $size]"
        }
      }

      subtest "f - create file with content" {
        machine succeed "echo 'f /tmp/test-f-content 0644 root root - hello world' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-f-content"]
        if {[string trim $content] ne "hello world"} {
          error "expected 'hello world', got '[string trim $content]'"
        }
      }

      subtest "f - does not overwrite existing file" {
        machine succeed "echo 'original' > /tmp/test-f-nooverwrite"
        machine succeed "echo 'f /tmp/test-f-nooverwrite 0644 root root - new content' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-f-nooverwrite"]
        if {[string trim $content] ne "original"} {
          error "f should not overwrite, got '[string trim $content]'"
        }
      }

      subtest "F - create/truncate file" {
        machine succeed "echo 'existing content' > /tmp/test-F"
        machine succeed "echo 'F /tmp/test-F 0644 root root - new content' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-F"]
        if {[string trim $content] ne "new content"} {
          error "F should truncate, got '[string trim $content]'"
        }
      }

      subtest "f+ - force create/truncate" {
        machine succeed "echo 'old' > /tmp/test-fplus"
        machine succeed "echo 'f+ /tmp/test-fplus 0644 root root - replaced' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-fplus"]
        if {[string trim $content] ne "replaced"} {
          error "f+ should replace, got '[string trim $content]'"
        }
      }

      # symlink tests (L, L+ types)

      subtest "L - create symlink" {
        machine succeed "echo 'L /tmp/test-link - - - - /etc/hostname' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -L /tmp/test-link"
        set target [machine succeed "readlink /tmp/test-link"]
        if {[string trim $target] ne "/etc/hostname"} {
          error "expected target /etc/hostname, got [string trim $target]"
        }
      }

      subtest "L - does not replace existing" {
        machine succeed "ln -sf /etc/passwd /tmp/test-link-noforce"
        machine succeed "echo 'L /tmp/test-link-noforce - - - - /etc/hostname' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set target [machine succeed "readlink /tmp/test-link-noforce"]
        if {[string trim $target] ne "/etc/passwd"} {
          error "L should not replace existing symlink"
        }
      }

      subtest "L+ - force replace symlink" {
        machine succeed "ln -sf /etc/passwd /tmp/test-link-force"
        machine succeed "echo 'L+ /tmp/test-link-force - - - - /etc/hostname' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set target [machine succeed "readlink /tmp/test-link-force"]
        if {[string trim $target] ne "/etc/hostname"} {
          error "L+ should force replace, got [string trim $target]"
        }
      }

      subtest "L+ - replace regular file with symlink" {
        machine succeed "echo 'blocker' > /tmp/test-link-replace"
        machine succeed "test -f /tmp/test-link-replace"
        machine fail "test -L /tmp/test-link-replace"
        machine succeed "echo 'L+ /tmp/test-link-replace - - - - /etc/hostname' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -L /tmp/test-link-replace"
      }

      # remove tests (r, R types)

      subtest "r - remove single file" {
        machine succeed "touch /tmp/test-r-file"
        machine succeed "test -f /tmp/test-r-file"
        machine succeed "echo 'r /tmp/test-r-file' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -e /tmp/test-r-file"
      }

      subtest "r - remove with glob pattern" {
        machine succeed "touch /tmp/glob-test-1.tmp /tmp/glob-test-2.tmp /tmp/glob-keep.txt"
        machine succeed "echo 'r /tmp/glob-test-*.tmp' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -e /tmp/glob-test-1.tmp"
        machine fail "test -e /tmp/glob-test-2.tmp"
        machine succeed "test -e /tmp/glob-keep.txt"
      }

      subtest "r - no error if file doesn't exist" {
        machine fail "test -e /tmp/nonexistent-file"
        machine succeed "echo 'r /tmp/nonexistent-file' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
      }

      subtest "R - recursive removal" {
        machine succeed "mkdir -p /tmp/test-R/a/b/c"
        machine succeed "touch /tmp/test-R/file1 /tmp/test-R/a/file2 /tmp/test-R/a/b/c/file3"
        machine succeed "echo 'R /tmp/test-R' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -e /tmp/test-R"
      }

      # age-based cleanup tests (--clean flag)

      subtest "clean - removes files older than age" {
        machine succeed "mkdir -p /tmp/test-age"
        # Create files with current timestamps
        machine succeed "touch /tmp/test-age/old-file"
        machine succeed "echo 'd /tmp/test-age 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles in the "future" (+2 days) so files appear old
        # NO_FAKE_STAT=1 ensures stat() returns real timestamps
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age/old-file"
        # Create new file AFTER cleanup to verify it would be kept
        machine succeed "touch /tmp/test-age/new-file"
        machine succeed "test -f /tmp/test-age/new-file"
      }

      subtest "clean - keeps files newer than age" {
        machine succeed "mkdir -p /tmp/test-age-keep"
        machine succeed "touch /tmp/test-age-keep/recent-file"
        machine succeed "echo 'd /tmp/test-age-keep 0755 root root 1d' > /tmp/test.conf"
        machine succeed "${tmpfiles} --clean /tmp/test.conf"
        machine succeed "test -f /tmp/test-age-keep/recent-file"
      }

      subtest "clean - age suffix 's' (seconds)" {
        machine succeed "mkdir -p /tmp/test-age-s"
        machine succeed "touch /tmp/test-age-s/old"
        machine succeed "echo 'd /tmp/test-age-s 0755 root root 60s' > /tmp/test.conf"
        # Run tmpfiles 2 minutes in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 minutes' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age-s/old"
      }

      subtest "clean - age suffix 'm' (minutes)" {
        machine succeed "mkdir -p /tmp/test-age-m"
        machine succeed "touch /tmp/test-age-m/old"
        machine succeed "echo 'd /tmp/test-age-m 0755 root root 5m' > /tmp/test.conf"
        # Run tmpfiles 10 minutes in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+10 minutes' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age-m/old"
      }

      subtest "clean - age suffix 'h' (hours)" {
        machine succeed "mkdir -p /tmp/test-age-h"
        machine succeed "touch /tmp/test-age-h/old"
        machine succeed "echo 'd /tmp/test-age-h 0755 root root 2h' > /tmp/test.conf"
        # Run tmpfiles 3 hours in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+3 hours' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age-h/old"
      }

      subtest "clean - age suffix 'w' (weeks)" {
        machine succeed "mkdir -p /tmp/test-age-w"
        machine succeed "touch /tmp/test-age-w/old"
        machine succeed "echo 'd /tmp/test-age-w 0755 root root 1w' > /tmp/test.conf"
        # Run tmpfiles 2 weeks in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 weeks' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age-w/old"
      }

      subtest "clean - age '-' means no cleanup" {
        machine succeed "mkdir -p /tmp/test-age-none"
        machine succeed "touch /tmp/test-age-none/ancient"
        machine succeed "echo 'd /tmp/test-age-none 0755 root root -' > /tmp/test.conf"
        # Even running far in the future, file should be kept because age is "-"
        machine succeed "NO_FAKE_STAT=1 faketime '+1 year' ${tmpfiles} --clean /tmp/test.conf"
        machine succeed "test -f /tmp/test-age-none/ancient"
      }

      subtest "clean - age '0' means no cleanup" {
        machine succeed "mkdir -p /tmp/test-age-zero"
        machine succeed "touch /tmp/test-age-zero/ancient"
        machine succeed "echo 'd /tmp/test-age-zero 0755 root root 0' > /tmp/test.conf"
        # Even running far in the future, file should be kept because age is "0"
        machine succeed "NO_FAKE_STAT=1 faketime '+1 year' ${tmpfiles} --clean /tmp/test.conf"
        machine succeed "test -f /tmp/test-age-zero/ancient"
      }

      subtest "clean - recursive cleanup" {
        machine succeed "mkdir -p /tmp/test-age-recursive/sub1/sub2"
        machine succeed "touch /tmp/test-age-recursive/root.txt"
        machine succeed "touch /tmp/test-age-recursive/sub1/mid.txt"
        machine succeed "touch /tmp/test-age-recursive/sub1/sub2/deep.txt"
        machine succeed "echo 'd /tmp/test-age-recursive 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so all files appear old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-age-recursive/root.txt"
        machine fail "test -f /tmp/test-age-recursive/sub1/mid.txt"
        machine fail "test -f /tmp/test-age-recursive/sub1/sub2/deep.txt"
      }

      subtest "clean - D type also cleans" {
        machine succeed "mkdir -p /tmp/test-D-clean"
        machine succeed "touch /tmp/test-D-clean/old"
        machine succeed "echo 'D /tmp/test-D-clean 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-D-clean/old"
        machine succeed "test -d /tmp/test-D-clean"
      }

      subtest "clean - e type cleans matching directories" {
        machine succeed "mkdir -p /tmp/test-e-clean"
        machine succeed "touch /tmp/test-e-clean/old"
        machine succeed "echo 'e /tmp/test-e-clean 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-e-clean/old"
      }

      subtest "clean - does not remove directory root itself" {
        machine succeed "mkdir -p /tmp/test-clean-root"
        machine succeed "touch /tmp/test-clean-root/file"
        machine succeed "echo 'd /tmp/test-clean-root 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine succeed "test -d /tmp/test-clean-root"
      }

      # write to file tests (w, w+ types)

      subtest "w - write to existing file" {
        machine succeed "touch /tmp/test-w"
        machine succeed "echo 'w /tmp/test-w - - - - content' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-w"]
        if {[string trim $content] ne "content"} {
          error "w should write content, got '[string trim $content]'"
        }
      }

      subtest "w+ - append to file" {
        machine succeed "echo 'line1' > /tmp/test-wplus"
        machine succeed "echo 'w+ /tmp/test-wplus - - - - line2' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-wplus"]
        if {![string match "*line1*" $content] || ![string match "*line2*" $content]} {
          error "w+ should append, got '$content'"
        }
      }

      # FIFO tests (p type)

      subtest "p - create FIFO" {
        machine succeed "echo 'p /tmp/test-fifo 0644 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -p /tmp/test-fifo"
      }

      # combined flags

      subtest "combined --create --remove --clean" {
        machine succeed "mkdir -p /tmp/test-combined"
        machine succeed "touch /tmp/test-combined/old"
        machine succeed "echo 'd /tmp/test-combined 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --create --remove --clean /tmp/test.conf"
        machine succeed "test -d /tmp/test-combined"
        machine fail "test -f /tmp/test-combined/old"
      }

      # idempotency

      subtest "idempotency - running create twice is safe" {
        machine succeed "echo 'd /tmp/test-idem 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -d /tmp/test-idem"
      }

      subtest "idempotency - file with content" {
        machine succeed "echo 'f /tmp/test-idem-file 0644 root root - test' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-idem-file"]
        if {[string trim $content] ne "test"} {
          error "content changed on second run"
        }
      }

      # escape sequences in file content

      subtest "escape - newline in content" {
        machine succeed "echo 'f /tmp/test-escape-n 0644 root root - line1\\nline2' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-escape-n"]
        if {![string match "*line1*" $content] || ![string match "*line2*" $content]} {
          error "newline escape failed: $content"
        }
      }

      subtest "escape - tab in content" {
        machine succeed "echo 'f /tmp/test-escape-t 0644 root root - col1\\tcol2' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-escape-t"]
        # Check that there's a tab between col1 and col2
        if {![string match "*col1*col2*" $content]} {
          error "tab escape failed: $content"
        }
      }

      subtest "escape - hex in content" {
        # \x41 = 'A', \x42 = 'B', \x43 = 'C'
        machine succeed "echo 'f /tmp/test-escape-hex 0644 root root - \\x41\\x42\\x43' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-escape-hex"]
        if {[string trim $content] ne "ABC"} {
          error "hex escape failed: expected ABC, got '$content'"
        }
      }

      subtest "escape - octal in content" {
        # \101 = 'A', \102 = 'B', \103 = 'C' (octal)
        machine succeed "echo 'f /tmp/test-escape-oct 0644 root root - \\101\\102\\103' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-escape-oct"]
        if {[string trim $content] ne "ABC"} {
          error "octal escape failed: expected ABC, got '$content'"
        }
      }

      subtest "escape - backslash in content" {
        machine succeed "echo 'f /tmp/test-escape-bs 0644 root root - back\\\\slash' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set content [machine succeed "cat /tmp/test-escape-bs"]
        if {![string match "*back\\\\slash*" $content] && ![string match "*back*slash*" $content]} {
          error "backslash escape failed: $content"
        }
      }

      # glob pattern tests

      subtest "glob - r with wildcard pattern" {
        machine succeed "mkdir -p /tmp/glob-r-test"
        machine succeed "touch /tmp/glob-r-test/file1.tmp /tmp/glob-r-test/file2.tmp /tmp/glob-r-test/keep.txt"
        machine succeed "echo 'r /tmp/glob-r-test/*.tmp' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -f /tmp/glob-r-test/file1.tmp"
        machine fail "test -f /tmp/glob-r-test/file2.tmp"
        machine succeed "test -f /tmp/glob-r-test/keep.txt"
      }

      subtest "glob - w writes to multiple matching files" {
        machine succeed "mkdir -p /tmp/glob-w-test"
        machine succeed "touch /tmp/glob-w-test/file1.txt /tmp/glob-w-test/file2.txt"
        machine succeed "echo 'w /tmp/glob-w-test/*.txt - - - - glob-content' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set c1 [machine succeed "cat /tmp/glob-w-test/file1.txt"]
        set c2 [machine succeed "cat /tmp/glob-w-test/file2.txt"]
        if {[string trim $c1] ne "glob-content" || [string trim $c2] ne "glob-content"} {
          error "glob write failed: c1='$c1' c2='$c2'"
        }
      }

      # e type - adjust existing directories

      subtest "e - adjust existing directory permissions" {
        machine succeed "mkdir -p /tmp/test-e-adjust"
        machine succeed "chmod 700 /tmp/test-e-adjust"
        set before [machine succeed "stat -c %a /tmp/test-e-adjust"]
        machine succeed "echo 'e /tmp/test-e-adjust 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set after [machine succeed "stat -c %a /tmp/test-e-adjust"]
        if {[string trim $after] ne "755"} {
          error "e should adjust mode, got [string trim $after]"
        }
      }

      subtest "e - does not create non-existent directory" {
        machine fail "test -d /tmp/test-e-nonexistent"
        machine succeed "echo 'e /tmp/test-e-nonexistent 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine fail "test -d /tmp/test-e-nonexistent"
      }

      subtest "e - with glob pattern" {
        machine succeed "mkdir -p /tmp/test-e-glob1 /tmp/test-e-glob2"
        machine succeed "chmod 700 /tmp/test-e-glob1 /tmp/test-e-glob2"
        machine succeed "echo 'e /tmp/test-e-glob* 0755 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set m1 [machine succeed "stat -c %a /tmp/test-e-glob1"]
        set m2 [machine succeed "stat -c %a /tmp/test-e-glob2"]
        if {[string trim $m1] ne "755" || [string trim $m2] ne "755"} {
          error "e glob failed: m1='$m1' m2='$m2'"
        }
      }

      # removal order independence

      subtest "r - removal order: parent before child" {
        machine succeed "mkdir -p /tmp/test-order/subdir"
        machine succeed "touch /tmp/test-order/subdir/file"
        # Remove parent directory listed before child
        machine succeed "printf 'R /tmp/test-order\\nr /tmp/test-order/subdir/file\\n' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -e /tmp/test-order"
      }

      subtest "r - removal order: child before parent" {
        machine succeed "mkdir -p /tmp/test-order2/subdir"
        machine succeed "touch /tmp/test-order2/subdir/file"
        # Remove child listed before parent directory
        machine succeed "printf 'r /tmp/test-order2/subdir/file\\nR /tmp/test-order2\\n' > /tmp/test.conf"
        machine succeed "${tmpfiles} --remove /tmp/test.conf"
        machine fail "test -e /tmp/test-order2"
      }

      # FIFO force replace (p+)

      subtest "p+ - force replace regular file with FIFO" {
        machine succeed "echo 'blocker' > /tmp/test-fifo-replace"
        machine succeed "test -f /tmp/test-fifo-replace"
        machine fail "test -p /tmp/test-fifo-replace"
        machine succeed "echo 'p+ /tmp/test-fifo-replace 0644 root root -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -p /tmp/test-fifo-replace"
      }

      # symlink edge cases

      subtest "L - relative symlink target" {
        machine succeed "mkdir -p /tmp/test-link-rel"
        machine succeed "touch /tmp/test-link-rel/target"
        machine succeed "echo 'L /tmp/test-link-rel/link - - - - target' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -L /tmp/test-link-rel/link"
        # Verify the link actually resolves
        machine succeed "test -e /tmp/test-link-rel/link"
      }

      subtest "L+ - replace directory with symlink" {
        machine succeed "mkdir -p /tmp/test-link-dir"
        machine succeed "touch /tmp/test-link-dir/file-inside"
        machine succeed "test -d /tmp/test-link-dir"
        machine succeed "echo 'L+ /tmp/test-link-dir - - - - /tmp' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -L /tmp/test-link-dir"
      }

      # multiple config files

      subtest "multiple config files on command line" {
        machine succeed "echo 'd /tmp/multi-test1 0755 root root -' > /tmp/test1.conf"
        machine succeed "echo 'd /tmp/multi-test2 0755 root root -' > /tmp/test2.conf"
        machine succeed "${tmpfiles} --create /tmp/test1.conf /tmp/test2.conf"
        machine succeed "test -d /tmp/multi-test1"
        machine succeed "test -d /tmp/multi-test2"
      }

      # age cleanup edge cases

      subtest "clean - empty directory is not removed" {
        machine succeed "mkdir -p /tmp/test-clean-empty"
        machine succeed "echo 'd /tmp/test-clean-empty 0755 root root 1s' > /tmp/test.conf"
        # Run tmpfiles 2 seconds in the future - directory itself should remain
        machine succeed "NO_FAKE_STAT=1 faketime '+2 seconds' ${tmpfiles} --clean /tmp/test.conf"
        machine succeed "test -d /tmp/test-clean-empty"
      }

      subtest "clean - nested old directories" {
        machine succeed "mkdir -p /tmp/test-clean-nested/a/b"
        machine succeed "touch /tmp/test-clean-nested/a/b/file"
        machine succeed "echo 'd /tmp/test-clean-nested 0755 root root 1d' > /tmp/test.conf"
        # Run tmpfiles 2 days in the future so file appears old
        machine succeed "NO_FAKE_STAT=1 faketime '+2 days' ${tmpfiles} --clean /tmp/test.conf"
        machine fail "test -f /tmp/test-clean-nested/a/b/file"
        # Root directory should remain
        machine succeed "test -d /tmp/test-clean-nested"
      }

      # ownership tests (user and group)

      subtest "d - create directory with specific user:group" {
        machine succeed "echo 'd /tmp/test-owner-d 0755 testuser testgroup -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -d /tmp/test-owner-d"
        set owner [machine succeed "stat -c %U:%G /tmp/test-owner-d"]
        if {[string trim $owner] ne "testuser:testgroup"} {
          error "expected testuser:testgroup, got [string trim $owner]"
        }
      }

      subtest "f - create file with specific user:group" {
        machine succeed "echo 'f /tmp/test-owner-f 0644 testuser testgroup - owned-content' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        machine succeed "test -f /tmp/test-owner-f"
        set owner [machine succeed "stat -c %U:%G /tmp/test-owner-f"]
        if {[string trim $owner] ne "testuser:testgroup"} {
          error "expected testuser:testgroup, got [string trim $owner]"
        }
      }

      subtest "d - user by name, group defaults to root" {
        machine succeed "echo 'd /tmp/test-owner-useronly 0755 testuser - -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set owner [machine succeed "stat -c %U:%G /tmp/test-owner-useronly"]
        if {[string trim $owner] ne "testuser:root"} {
          error "expected testuser:root, got [string trim $owner]"
        }
      }

      subtest "d - defaults to root:root with dash" {
        machine succeed "echo 'd /tmp/test-owner-dash 0755 - - -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set owner [machine succeed "stat -c %U:%G /tmp/test-owner-dash"]
        if {[string trim $owner] ne "root:root"} {
          error "expected root:root, got [string trim $owner]"
        }
      }

      subtest "e - adjust ownership on existing directory" {
        machine succeed "mkdir -p /tmp/test-owner-e"
        machine succeed "chown root:root /tmp/test-owner-e"
        set before [machine succeed "stat -c %U:%G /tmp/test-owner-e"]
        machine succeed "echo 'e /tmp/test-owner-e 0755 testuser testgroup -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set after [machine succeed "stat -c %U:%G /tmp/test-owner-e"]
        if {[string trim $after] ne "testuser:testgroup"} {
          error "e should adjust ownership, got [string trim $after]"
        }
      }

      subtest "ownership - numeric uid:gid" {
        machine succeed "echo 'd /tmp/test-owner-numeric 0755 1234 5678 -' > /tmp/test.conf"
        machine succeed "${tmpfiles} --create /tmp/test.conf"
        set uid [machine succeed "stat -c %u /tmp/test-owner-numeric"]
        set gid [machine succeed "stat -c %g /tmp/test-owner-numeric"]
        if {[string trim $uid] ne "1234" || [string trim $gid] ne "5678"} {
          error "expected uid=1234 gid=5678, got uid=[string trim $uid] gid=[string trim $gid]"
        }
      }

      # error handling

      subtest "error - requires at least one action flag" {
        machine succeed "echo 'd /tmp/foo 0755 root root -' > /tmp/test.conf"
        machine fail "${tmpfiles} /tmp/test.conf"
      }

      # cleanup and shutdown

      subtest "shutdown" {
        machine shutdown 60
      }

      success
    '';
}
