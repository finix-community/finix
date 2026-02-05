# tests for finit remain:yes feature (RemainAfterExit equivalent)
#
# tests that tasks with remain:yes stay active after completion,
# run post: scripts on stop, and handle runlevel transitions correctly.
{
  name = "finit.remain-after-exit";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../lib/common.nix ];

      # test task with remain:yes that runs in runlevels S and 2
      finit.tasks.test-remain = {
        runlevels = "S2";
        command = pkgs.writeShellScript "test-remain-start" ''
          echo "remain task started" > /run/remain-test/started
          echo "setting up resources"
        '';
        post = pkgs.writeShellScript "test-remain-stop" ''
          echo "remain task stopped" > /run/remain-test/stopped
          echo "cleaning up resources"
        '';
        remain = true;
        description = "Test task with remain:yes";
      };

      # test task with remain:yes for runlevels 2 and 3
      finit.tasks.multi-runlevel = {
        runlevels = "23";
        command = pkgs.writeShellScript "multi-rl-start" ''
          echo "multi-runlevel started in rl $(cat /run/finit/runlevel 2>/dev/null || echo unknown)" > /run/remain-test/multi-rl
        '';
        post = pkgs.writeShellScript "multi-rl-stop" ''
          echo "multi-runlevel cleanup" > /run/remain-test/multi-rl-cleanup
        '';
        remain = true;
        description = "Multi-runlevel remain task";
      };

      # service that depends on the remain task
      finit.services.dependent-service = {
        runlevels = "2";
        conditions = "task/test-remain/success";
        command = pkgs.writeShellScript "dependent-service" ''
          echo "dependent service started" > /run/remain-test/dependent
          exec sleep infinity
        '';
        description = "Service depending on remain task";
      };

      # regular task (no remain) for comparison
      finit.tasks.regular-task = {
        runlevels = "S2";
        command = pkgs.writeShellScript "regular-task" ''
          echo "regular task ran" > /run/remain-test/regular
        '';
        post = pkgs.writeShellScript "regular-post" ''
          echo "regular post ran" > /run/remain-test/regular-post
        '';
        description = "Regular task without remain";
      };

      # create test directory at boot
      finit.tmpfiles.rules = [
        "d /run/remain-test 0755 root root -"
      ];
    };

  testScript = ''
    import json
    import time

    def get_status(name):
        """Get service/task status as parsed JSON"""
        output = machine.succeed(f"initctl -j status {name}")
        return json.loads(output)

    machine.start()

    # wait for full boot sequence
    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")

    # basic remain task functionality

    with subtest("remain task completes and stays active"):
        # task should have run
        machine.succeed("test -f /run/remain-test/started")
        content = machine.succeed("cat /run/remain-test/started")
        assert "remain task started" in content, f"expected 'remain task started', got: {content}"

        # post script should NOT have run yet (task still active)
        machine.fail("test -f /run/remain-test/stopped")

        # task should be in done state (not halted)
        status = get_status("test-remain")
        assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

    with subtest("remain task condition is asserted"):
        # check that the success condition exists
        machine.succeed("test -f /run/finit/cond/task/test-remain/success")

    with subtest("remain task condition persists after reload"):
        # get condition status before reload
        cond_dump = json.loads(machine.succeed("initctl -j cond dump"))
        cond = next((c for c in cond_dump if c["condition"] == "task/test-remain/success"), None)
        assert cond is not None, "task/test-remain/success condition not found before reload"
        assert cond["status"] == "on", f"expected condition status 'on' before reload, got: {cond['status']}"

        # trigger a reload
        machine.succeed("initctl reload")
        time.sleep(2)  # give time for reload to complete

        # check condition status after reload - should still be "on", not "flux"
        cond_dump = json.loads(machine.succeed("initctl -j cond dump"))
        cond = next((c for c in cond_dump if c["condition"] == "task/test-remain/success"), None)
        assert cond is not None, "task/test-remain/success condition not found after reload"
        assert cond["status"] == "on", f"expected condition status 'on' after reload, got: {cond['status']} (condition entered flux state - bug!)"

    with subtest("dependent service started due to condition"):
        # service depending on remain task should be running
        machine.succeed("test -f /run/remain-test/dependent")
        status = get_status("dependent-service")
        assert status["status"] == "running", f"expected status 'running', got: {status['status']}"

    # config modification + reload behavior (test before runlevel changes to ensure clean state)

    with subtest("remain task in done state restarts when config modified and reloaded"):
        # create scripts for this test in writable location
        machine.succeed("echo '#!/bin/sh' > /run/remain-test/start-v1.sh")
        machine.succeed("echo 'echo version1 > /run/remain-test/modifiable-version' >> /run/remain-test/start-v1.sh")
        machine.succeed("chmod +x /run/remain-test/start-v1.sh")

        machine.succeed("echo '#!/bin/sh' > /run/remain-test/start-v2.sh")
        machine.succeed("echo 'echo version2 > /run/remain-test/modifiable-version' >> /run/remain-test/start-v2.sh")
        machine.succeed("chmod +x /run/remain-test/start-v2.sh")

        machine.succeed("echo '#!/bin/sh' > /run/remain-test/post.sh")
        machine.succeed("echo 'echo cleanup >> /run/remain-test/modifiable-cleanup' >> /run/remain-test/post.sh")
        machine.succeed("chmod +x /run/remain-test/post.sh")

        # create initial config in /etc/finit.d/
        machine.succeed("echo 'task [2] remain:yes name:modifiable-remain post:/run/remain-test/post.sh /run/remain-test/start-v1.sh -- Modifiable remain task' > /etc/finit.d/modifiable-remain.conf")

        # reload to pick up the new task
        machine.succeed("initctl reload")
        time.sleep(3)

        # verify task ran with version1
        machine.succeed("test -f /run/remain-test/modifiable-version")
        content = machine.succeed("cat /run/remain-test/modifiable-version")
        assert "version1" in content, f"expected 'version1', got: {content}"

        status = get_status("modifiable-remain")
        assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

        # post script should NOT have run yet
        machine.fail("test -f /run/remain-test/modifiable-cleanup")


        # modify the config to use version2 script
        machine.succeed("echo 'task [2] remain:yes name:modifiable-remain post:/run/remain-test/post.sh /run/remain-test/start-v2.sh -- Modifiable remain task' > /etc/finit.d/modifiable-remain.conf")

        # small delay to ensure inotify processes the file change
        time.sleep(1)

        # reload to trigger the config change detection
        machine.succeed("initctl reload")
        time.sleep(5)  # wait for post script to complete and task to restart

        # post script should have run (cleanup from old config)
        machine.succeed("test -f /run/remain-test/modifiable-cleanup")
        cleanup_content = machine.succeed("cat /run/remain-test/modifiable-cleanup")
        assert "cleanup" in cleanup_content, f"expected 'cleanup', got: {cleanup_content}"

        # task should have re-run with new config (version2)
        content = machine.succeed("cat /run/remain-test/modifiable-version")
        assert "version2" in content, f"expected 'version2' after reload, got: {content}"

        # task should be back in done state
        status = get_status("modifiable-remain")
        assert status["status"] == "done", f"expected status 'done' after restart, got: {status['status']}"

    # multi-runlevel task behavior

    with subtest("multi-runlevel remain task is active in runlevel 2"):
        machine.succeed("test -f /run/remain-test/multi-rl")
        machine.fail("test -f /run/remain-test/multi-rl-cleanup")
        status = get_status("multi-runlevel")
        assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

    with subtest("switching to runlevel 3 does not trigger post script for multi-runlevel task"):
        # switch to runlevel 3
        machine.succeed("initctl runlevel 3")
        machine.wait_for_console_text("entering runlevel 3")

        time.sleep(2)  # give time for state machine to settle

        # post script should NOT have run (task is valid in both 2 and 3)
        machine.fail("test -f /run/remain-test/multi-rl-cleanup")

        # task should still be in done state
        status = get_status("multi-runlevel")
        assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

    with subtest("switching to runlevel 4 triggers post script for multi-runlevel task"):
        # switch to runlevel 4 (task is only valid in 2 and 3)
        machine.succeed("initctl runlevel 4")
        machine.wait_for_console_text("entering runlevel 4")

        time.sleep(2)  # give time for post script to run

        # NOW the post script should have run
        machine.succeed("test -f /run/remain-test/multi-rl-cleanup")

    # explicit stop behavior

    with subtest("explicit stop triggers post script"):
        # switch back to runlevel 2 where test-remain is valid
        machine.succeed("initctl runlevel 2")
        machine.wait_for_console_text("entering runlevel 2")

        time.sleep(2)

        # test-remain should still be active (it was valid in 2 before and after)
        status = get_status("test-remain")
        assert status["status"] == "done", f"expected status 'done' before stop, got: {status['status']}"

        # explicitly stop the remain task
        machine.succeed("initctl stop test-remain")

        time.sleep(1)

        # post script should now have run
        machine.succeed("test -f /run/remain-test/stopped")
        content = machine.succeed("cat /run/remain-test/stopped")
        assert "remain task stopped" in content, f"expected 'remain task stopped', got: {content}"

    # regular task comparison

    with subtest("regular task (no remain) does not run post on completion"):
        # regular task should have run
        machine.succeed("test -f /run/remain-test/regular")

        # for regular tasks, post script does NOT run on normal completion
        # (only on explicit stop for services, not tasks without remain)
        # This verifies that the remain:yes behavior is different
        machine.fail("test -f /run/remain-test/regular-post")

    with subtest("shutdown"):
        machine.shutdown()
  '';
}
