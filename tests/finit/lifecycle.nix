{
  name = "finit.lifecycle";

  nodes.machine =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.mdevd.enable = true;

      finit.tmpfiles.rules = [
        "d /run/finit-lifecycle 0755 root root -"
      ];

      finit.services.lifecycle-no-retry = {
        runlevel = "2";
        restart-max = 0;
        command = pkgs.writeShellScript "finit-lifecycle-no-retry" ''
          count=0
          if [ -f /run/finit-lifecycle/no-retry.count ]; then
            count=$(${pkgs.coreutils}/bin/cat /run/finit-lifecycle/no-retry.count)
          fi
          count=$((count + 1))
          printf '%s\n' "$count" > /run/finit-lifecycle/no-retry.count
          printf '%s\n' failed > /run/finit-lifecycle/no-retry.marker
          exit 42
        '';
      };

      finit.services.lifecycle-limited = {
        runlevel = "2";
        restart-max = 1;
        command = pkgs.writeShellScript "finit-lifecycle-limited" ''
          count=0
          if [ -f /run/finit-lifecycle/limited.count ]; then
            count=$(${pkgs.coreutils}/bin/cat /run/finit-lifecycle/limited.count)
          fi
          count=$((count + 1))
          printf '%s\n' "$count" > /run/finit-lifecycle/limited.count
          printf '%s\n' crashed > /run/finit-lifecycle/limited.marker
          exit 43
        '';
      };

      finit.services.lifecycle-reload = {
        runlevel = "2";
        exec-reload = pkgs.writeShellScript "finit-lifecycle-reload" ''
          printf '%s\n' "$MAINPID" >> /run/finit-lifecycle/reload-exec.pids
          kill -HUP "$MAINPID"
        '';
        command = pkgs.writeShellScript "finit-lifecycle-reload-service" ''
          trap 'printf "%s\n" hup >> /run/finit-lifecycle/reload.hups' HUP
          trap 'exit 0' TERM INT
          printf '%s\n' "$$" > /run/finit-lifecycle/reload.pid
          while :; do
            ${pkgs.coreutils}/bin/sleep 1
          done
        '';
      };

      finit.services.lifecycle-provider = {
        runlevel = "2";
        notify = "pid";
        pidfile = "/run/finit-lifecycle/provider.pid";
        exec-reload = pkgs.writeShellScript "finit-lifecycle-provider-reload" ''
          printf '%s\n' "$MAINPID" >> /run/finit-lifecycle/provider-reload.pids
          kill -HUP "$MAINPID"
        '';
        command = pkgs.writeShellScript "finit-lifecycle-provider" ''
          reload() {
            printf '%s\n' hup >> /run/finit-lifecycle/provider.hups
            ${pkgs.coreutils}/bin/rm -f /run/finit-lifecycle/provider.pid
            ${pkgs.coreutils}/bin/sleep 1
            printf '%s\n' "$$" > /run/finit-lifecycle/provider.pid
          }
          trap '${pkgs.coreutils}/bin/rm -f /run/finit-lifecycle/provider.pid; exit 0' TERM INT
          trap reload HUP
          printf '%s\n' "$$" > /run/finit-lifecycle/provider.pid
          while :; do
            ${pkgs.coreutils}/bin/sleep 1
          done
        '';
      };

      finit.services.lifecycle-dependent = {
        runlevel = "2";
        conditions = [ "service/lifecycle-provider/ready" ];
        exec-reload = pkgs.writeShellScript "finit-lifecycle-dependent-reload" ''
          printf '%s\n' "$MAINPID" >> /run/finit-lifecycle/dependent-reload.pids
          kill -HUP "$MAINPID"
        '';
        command = pkgs.writeShellScript "finit-lifecycle-dependent" ''
          trap 'exit 0' TERM INT
          trap 'printf "%s\n" hup >> /run/finit-lifecycle/dependent.hups' HUP
          printf '%s\n' started > /run/finit-lifecycle/dependent.marker
          while :; do
            ${pkgs.coreutils}/bin/sleep 1
          done
        '';
      };

      finit.services.lifecycle-stale = {
        runlevel = "2";
        notify = "pid";
        pidfile = "/run/finit-lifecycle/stale.pid";
        restart-max = 1;
        command = pkgs.writeShellScript "finit-lifecycle-stale" ''
          if [ -e /run/finit-lifecycle/stale.pid ]; then
            printf '%s\n' refused >> /run/finit-lifecycle/stale.refused
            exit 44
          fi
          trap '${pkgs.coreutils}/bin/rm -f /run/finit-lifecycle/stale.pid; exit 0' TERM INT
          trap ':' HUP
          printf '%s\n' "$$" >> /run/finit-lifecycle/stale.starts
          printf '%s\n' "$$" > /run/finit-lifecycle/stale.pid
          while :; do
            ${pkgs.coreutils}/bin/sleep 0.1
          done
        '';
      };

      finit.services.lifecycle-hooks = {
        runlevel = "2";
        manual-start = true;
        exec-reload = pkgs.writeShellScript "finit-lifecycle-hooks-reload" ''
          printf '%s\n' "$MAINPID" > /run/finit-lifecycle/hooks-reload.pid
          kill -HUP "$MAINPID"
        '';
        exec-stop = pkgs.writeShellScript "finit-lifecycle-hooks-stop" ''
          printf '%s\n' "$MAINPID" > /run/finit-lifecycle/hooks-stop.pid
          kill -TERM "$MAINPID"
        '';
        command = pkgs.writeShellScript "finit-lifecycle-hooks" ''
          printf '%s\n' "$$" > /run/finit-lifecycle/hooks.pid
          trap 'exit 0' TERM INT
          trap ':' HUP
          while :; do
            ${pkgs.coreutils}/bin/sleep 1
          done
        '';
      };
    };

  testScript = ''
    from datetime import timedelta
    import json
    import time

    WAIT = timedelta(seconds=30)
    BOOT = timedelta(seconds=180)

    def json_status(name):
        return json.loads(machine.succeed(f"initctl -j status {name}"))

    def wait_status(name, states, predicate=lambda status: True):
        deadline = time.monotonic() + WAIT.total_seconds()
        status = json_status(name)
        while time.monotonic() < deadline:
            status = json_status(name)
            if status["status"] in states and predicate(status):
                return status
            time.sleep(0.1)
        raise AssertionError(f"{name} did not reach {states}: {status}")

    def line_count(path):
        return int(machine.succeed(f"wc -l < /run/finit-lifecycle/{path}"))

    def condition_status(name):
        conditions = json.loads(machine.succeed("initctl -j cond dump"))
        condition = next(
            (item for item in conditions if item["condition"] == name), None
        )
        assert condition is not None, f"condition {name} not found"
        return condition["status"]

    def wait_condition_status(name, expected):
        deadline = time.monotonic() + WAIT.total_seconds()
        current = condition_status(name)
        while time.monotonic() < deadline:
            current = condition_status(name)
            if current == expected:
                return
            time.sleep(0.1)
        raise AssertionError(
            f"condition {name} did not reach {expected}; got {current}"
        )

    def writable_conf(name):
        path = f"/etc/finit.d/{name}.conf"
        machine.succeed(f"cp -L {path} {path}.fixture && chmod u+w {path}.fixture")
        machine.succeed(f"mv -Tf {path}.fixture {path}")
        machine.succeed(f"test ! -L {path} && test -w {path}")

    machine.start()
    machine.wait_for_console_text("finix - stage 1", timeout=BOOT)
    machine.wait_for_console_text("finix - stage 2", timeout=BOOT)
    machine.wait_for_console_text("entering runlevel S", timeout=BOOT)
    machine.wait_for_console_text("entering runlevel 2", timeout=BOOT)

    with subtest("restart-max zero forbids retries"):
        status = wait_status("lifecycle-no-retry", {"crashed", "stopped"})
        assert status["pid"] == 0, status
        assert status["exit"]["code"] == 42, status
        assert int(machine.succeed("cat /run/finit-lifecycle/no-retry.count")) == 1
        machine.succeed("test -f /run/finit-lifecycle/no-retry.marker")

    with subtest("restart-max one permits one retry"):
        status = wait_status("lifecycle-limited", {"crashed", "stopped"})
        assert status["pid"] == 0, status
        assert status["exit"]["code"] == 43, status
        count = int(machine.succeed("cat /run/finit-lifecycle/limited.count"))
        assert count == 2, f"restart-max=1 allowed unexpected starts: count={count}"
        machine.succeed("test -f /run/finit-lifecycle/limited.marker")

    with subtest("exec-reload receives MAINPID without restarting service"):
        pid_before = wait_status("lifecycle-reload", {"running"})["pid"]
        assert pid_before > 1
        machine.wait_until_succeeds("test -s /run/finit-lifecycle/reload.pid", timeout=WAIT)
        assert int(machine.succeed("cat /run/finit-lifecycle/reload.pid")) == pid_before
        writable_conf("lifecycle-reload")
        machine.succeed("initctl touch lifecycle-reload.conf")
        machine.succeed("initctl reload lifecycle-reload")
        machine.wait_until_succeeds(
            "test \"$(wc -l < /run/finit-lifecycle/reload-exec.pids)\" -eq 1",
            timeout=WAIT,
        )
        machine.wait_until_succeeds(
            "test \"$(wc -l < /run/finit-lifecycle/reload.hups)\" -eq 1",
            timeout=WAIT,
        )
        pid_after = json_status("lifecycle-reload")["pid"]
        assert pid_after == pid_before, (
            f"exec-reload restarted service: before={pid_before}, after={pid_after}"
        )
        assert int(machine.succeed("cat /run/finit-lifecycle/reload-exec.pids")) == pid_before

    with subtest("provider readiness starts dependent service"):
        provider_pid = wait_status("lifecycle-provider", {"running"})["pid"]
        wait_status("lifecycle-dependent", {"running"})
        machine.wait_until_succeeds("test -f /run/finit-lifecycle/dependent.marker", timeout=WAIT)
        wait_condition_status("service/lifecycle-provider/ready", "on")
        assert provider_pid > 1

    with subtest("reload propagates through provider and dependent service"):
        machine.succeed(
            "rm -f /run/finit-lifecycle/provider.hups "
            "/run/finit-lifecycle/provider-reload.pids "
            "/run/finit-lifecycle/dependent-reload.pids "
            "/run/finit-lifecycle/dependent.hups"
        )
        for name in ("lifecycle-provider", "lifecycle-dependent"):
            writable_conf(name)
            machine.succeed(f"initctl touch {name}.conf")

        machine.succeed("initctl reload && initctl reload")
        wait_status("lifecycle-provider", {"running"})
        wait_status("lifecycle-dependent", {"running"})
        assert line_count("provider-reload.pids") == 1
        assert line_count("provider.hups") == 1
        assert json_status("lifecycle-provider")["pid"] == provider_pid
        assert json_status("lifecycle-dependent")["pid"] > 1

    with subtest("Finit removes daemon-owned stale pidfile after SIGKILL"):
        wait_condition_status("service/lifecycle-stale/ready", "on")
        old_pid = wait_status("lifecycle-stale", {"running"})["pid"]
        assert old_pid > 1
        assert int(machine.succeed("cat /run/finit-lifecycle/stale.pid")) == old_pid
        assert line_count("stale.starts") == 1
        machine.succeed(f"kill -KILL {old_pid}")
        restarted = wait_status(
            "lifecycle-stale", {"running"},
            lambda status: status["pid"] > 1 and status["pid"] != old_pid,
        )
        new_pid = restarted["pid"]
        machine.wait_until_succeeds(
            f"test \"$(cat /run/finit-lifecycle/stale.pid)\" -eq {new_pid}", timeout=WAIT
        )
        machine.succeed(f"kill -0 {new_pid}")
        wait_condition_status("service/lifecycle-stale/ready", "on")
        assert line_count("stale.starts") == 2
        machine.fail("test -e /run/finit-lifecycle/stale.refused")

    with subtest("reload and stop hooks keep PID1 responsive"):
        machine.succeed("initctl start lifecycle-hooks")
        pid = wait_status("lifecycle-hooks", {"running"})["pid"]
        assert pid > 1
        machine.wait_until_succeeds("test -s /run/finit-lifecycle/hooks.pid", timeout=WAIT)
        machine.succeed("initctl reload lifecycle-hooks")
        machine.wait_until_succeeds("test -s /run/finit-lifecycle/hooks-reload.pid", timeout=WAIT)
        assert int(machine.succeed("cat /run/finit-lifecycle/hooks-reload.pid")) == pid
        assert json_status("lifecycle-hooks")["pid"] == pid
        machine.succeed("kill -0 1 && initctl status")
        machine.succeed("initctl stop lifecycle-hooks")
        wait_status("lifecycle-hooks", {"stopped"})
        assert int(machine.succeed("cat /run/finit-lifecycle/hooks-stop.pid")) == pid
        machine.succeed("kill -0 1 && initctl status")

    with subtest("shutdown"):
        machine.shutdown()
  '';
}
