{ ... }:
{
  config.testing.tests.finit.remain-after-exit = {
    nodes.machine =
      { pkgs, ... }:
      {
        services.mdevd.enable = true;

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

        finit.services.dependent-service = {
          runlevels = "2";
          conditions = "task/test-remain/success";
          command = pkgs.writeShellScript "dependent-service" ''
            echo "dependent service started" > /run/remain-test/dependent
            exec sleep infinity
          '';
          description = "Service depending on remain task";
        };

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

        finit.tmpfiles.rules = [
          "d /run/remain-test 0755 root root -"
        ];
      };

    testScript = ''
      import json
      import time

      def get_status(name):
          output = machine.succeed(f"initctl -j status {name}")
          return json.loads(output)

      machine.start()

      machine.wait_for_console_text("finix - stage 1")
      machine.wait_for_console_text("finix - stage 2")
      machine.wait_for_console_text("entering runlevel S")
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("remain task completes and stays active"):
          machine.succeed("test -f /run/remain-test/started")
          content = machine.succeed("cat /run/remain-test/started")
          assert "remain task started" in content, f"expected 'remain task started', got: {content}"
          machine.fail("test -f /run/remain-test/stopped")
          status = get_status("test-remain")
          assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

      with subtest("remain task condition is asserted"):
          machine.succeed("test -f /run/finit/cond/task/test-remain/success")

      with subtest("remain task condition persists after reload"):
          cond_dump = json.loads(machine.succeed("initctl -j cond dump"))
          cond = next((c for c in cond_dump if c["condition"] == "task/test-remain/success"), None)
          assert cond is not None, "task/test-remain/success condition not found before reload"
          assert cond["status"] == "on", f"expected condition status 'on' before reload, got: {cond['status']}"

          machine.succeed("initctl reload")
          time.sleep(2)

          cond_dump = json.loads(machine.succeed("initctl -j cond dump"))
          cond = next((c for c in cond_dump if c["condition"] == "task/test-remain/success"), None)
          assert cond is not None, "task/test-remain/success condition not found after reload"
          assert cond["status"] == "on", f"expected condition status 'on' after reload, got: {cond['status']}"

      with subtest("dependent service started due to condition"):
          machine.succeed("test -f /run/remain-test/dependent")
          status = get_status("dependent-service")
          assert status["status"] == "running", f"expected status 'running', got: {status['status']}"

      with subtest("remain task in done state restarts when config modified and reloaded"):
          machine.succeed("echo '#!/bin/sh' > /run/remain-test/start-v1.sh")
          machine.succeed("echo 'echo version1 > /run/remain-test/modifiable-version' >> /run/remain-test/start-v1.sh")
          machine.succeed("chmod +x /run/remain-test/start-v1.sh")
          machine.succeed("echo '#!/bin/sh' > /run/remain-test/start-v2.sh")
          machine.succeed("echo 'echo version2 > /run/remain-test/modifiable-version' >> /run/remain-test/start-v2.sh")
          machine.succeed("chmod +x /run/remain-test/start-v2.sh")
          machine.succeed("echo '#!/bin/sh' > /run/remain-test/post.sh")
          machine.succeed("echo 'echo cleanup >> /run/remain-test/modifiable-cleanup' >> /run/remain-test/post.sh")
          machine.succeed("chmod +x /run/remain-test/post.sh")

          machine.succeed("echo 'task [2] remain:yes name:modifiable-remain post:/run/remain-test/post.sh /run/remain-test/start-v1.sh -- Modifiable remain task' > /etc/finit.d/modifiable-remain.conf")
          machine.succeed("initctl reload")
          time.sleep(3)

          machine.succeed("test -f /run/remain-test/modifiable-version")
          content = machine.succeed("cat /run/remain-test/modifiable-version")
          assert "version1" in content, f"expected 'version1', got: {content}"
          status = get_status("modifiable-remain")
          assert status["status"] == "done", f"expected status 'done', got: {status['status']}"
          machine.fail("test -f /run/remain-test/modifiable-cleanup")

          machine.succeed("echo 'task [2] remain:yes name:modifiable-remain post:/run/remain-test/post.sh /run/remain-test/start-v2.sh -- Modifiable remain task' > /etc/finit.d/modifiable-remain.conf")
          time.sleep(1)
          machine.succeed("initctl reload")
          time.sleep(5)

          machine.succeed("test -f /run/remain-test/modifiable-cleanup")
          cleanup_content = machine.succeed("cat /run/remain-test/modifiable-cleanup")
          assert "cleanup" in cleanup_content, f"expected 'cleanup', got: {cleanup_content}"
          content = machine.succeed("cat /run/remain-test/modifiable-version")
          assert "version2" in content, f"expected 'version2' after reload, got: {content}"
          status = get_status("modifiable-remain")
          assert status["status"] == "done", f"expected status 'done' after restart, got: {status['status']}"

      with subtest("multi-runlevel remain task is active in runlevel 2"):
          machine.succeed("test -f /run/remain-test/multi-rl")
          machine.fail("test -f /run/remain-test/multi-rl-cleanup")
          status = get_status("multi-runlevel")
          assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

      with subtest("switching to runlevel 3 does not trigger post script for multi-runlevel task"):
          machine.succeed("initctl runlevel 3")
          machine.wait_for_console_text("entering runlevel 3")
          time.sleep(2)
          machine.fail("test -f /run/remain-test/multi-rl-cleanup")
          status = get_status("multi-runlevel")
          assert status["status"] == "done", f"expected status 'done', got: {status['status']}"

      with subtest("switching to runlevel 4 triggers post script for multi-runlevel task"):
          machine.succeed("initctl runlevel 4")
          machine.wait_for_console_text("entering runlevel 4")
          time.sleep(2)
          machine.succeed("test -f /run/remain-test/multi-rl-cleanup")

      with subtest("explicit stop triggers post script"):
          machine.succeed("initctl runlevel 2")
          machine.wait_for_console_text("entering runlevel 2")
          time.sleep(2)
          status = get_status("test-remain")
          assert status["status"] == "done", f"expected status 'done' before stop, got: {status['status']}"
          machine.succeed("initctl stop test-remain")
          time.sleep(1)
          machine.succeed("test -f /run/remain-test/stopped")
          content = machine.succeed("cat /run/remain-test/stopped")
          assert "remain task stopped" in content, f"expected 'remain task stopped', got: {content}"

      with subtest("regular task (no remain) does not run post on completion"):
          machine.succeed("test -f /run/remain-test/regular")
          machine.fail("test -f /run/remain-test/regular-post")

      machine.shutdown()
    '';
  };
}
