# test for shell command execution
#
# this test verifies that the test driver can execute commands
# inside the vm via the shell socket.
{
  name = "shell";

  nodes.machine =
    { ... }:
    {
      imports = [ ./lib/common.nix ];
    };

  testScript = ''
    machine.start()
    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")

    with subtest("succeed returns command output"):
        output = machine.succeed("echo hello")
        assert output.strip() == "hello", f"expected 'hello', got: {output}"

    with subtest("succeed handles multi-line output"):
        output = machine.succeed("echo -e 'line1\\nline2\\nline3'")
        assert "line1" in output and "line3" in output, f"multi-line output failed: {output}"

    with subtest("fail detects non-zero exit"):
        machine.fail("exit 1")
        machine.fail("test -f /nonexistent")

    with subtest("execute returns status and output"):
        status, output = machine.execute("echo test; exit 0")
        assert status == 0, f"expected status 0, got: {status}"
        status, output = machine.execute("exit 42")
        assert status == 42, f"expected status 42, got: {status}"

    with subtest("wait_for_file"):
        machine.wait_for_file("/etc/passwd")

    with subtest("file creation and content"):
        machine.succeed("echo 'test content' > /tmp/test-file")
        content = machine.succeed("cat /tmp/test-file")
        assert "test content" in content, f"file content mismatch: {content}"

    with subtest("environment variables"):
        user = machine.succeed("echo $USER")
        assert user.strip() == "root", f"expected USER=root, got: {user}"

    with subtest("wait_until_succeeds"):
        machine.wait_until_succeeds("test -f /etc/passwd", timeout=10)

    with subtest("shutdown"):
        machine.shutdown()
  '';
}
