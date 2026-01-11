# test for shell command execution.
#
# this test verifies that the test driver can execute commands
# inside the vm via the shell socket
{
  name = "finix-test-driver.shell";

  nodes.machine = {
    finit.runlevel = 2;
    services.mdevd.enable = true;
  };

  testScript = ''
    machine start
    machine expect -timeout 30 "entering runlevel 2"
    after 500

    subtest "succeed returns command output" {
      set output [machine succeed "echo hello"]
      if {[string trim $output] ne "hello"} {
        error "expected 'hello', got: $output"
      }
    }

    subtest "succeed handles multi-line output" {
      set output [machine succeed "echo -e 'line1\nline2\nline3'"]
      if {![string match "*line1*" $output] || ![string match "*line3*" $output]} {
        error "multi-line output failed: $output"
      }
    }

    subtest "fail detects non-zero exit" {
      machine fail "exit 1"
      machine fail "test -f /nonexistent"
    }

    subtest "execute returns status and output" {
      lassign [machine execute "echo test; exit 0"] status output
      if {$status != 0} {
        error "expected status 0, got: $status"
      }
      lassign [machine execute "exit 42"] status output
      if {$status != 42} {
        error "expected status 42, got: $status"
      }
    }

    subtest "waitForFile" {
      machine waitForFile "/etc/passwd" 30
    }

    subtest "file creation and content" {
      machine succeed "echo 'test content' > /tmp/test-file"
      set content [machine succeed "cat /tmp/test-file"]
      if {![string match "*test content*" $content]} {
        error "file content mismatch: $content"
      }
    }

    subtest "environment variables" {
      set user [machine succeed "echo \$USER"]
      if {[string trim $user] ne "root"} {
        error "expected USER=root, got: $user"
      }
    }

    subtest "waitForCondition" {
      machine waitForCondition "task/test-network/success" 30
    }

    subtest "shutdown" {
      machine shutdown 60
    }

    success
  '';
}
