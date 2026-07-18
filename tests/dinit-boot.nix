# test that the system boots successfully with dinit as PID 1
#
# verifies the dinit module generates a bootable service set:
# boot target comes up, boot.d services start, and the activation
# scripts (dinitBootD symlink creation) ran.
{
  name = "dinit-boot";

  nodes.machine =
    { pkgs, ... }:
    {
      # all finix modules (incl. dinit) are already imported by the test harness
      finit.enable = false;

      services.mdevd.enable = true;

      # a trivial service that must come up as part of the boot target
      dinit.services.testsvc = {
        command = "${pkgs.coreutils}/bin/sleep infinity";
        boot = true;
        restart = true;
      };
    };

  testScript = ''
    machine.start()

    # dinit prints service start notifications to the console (regex-escaped)
    machine.wait_for_console_text("\\[  OK  \\] boot")

    # boot target and its boot.d dependencies should be up
    machine.wait_until_succeeds("dinitctl status boot | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status mount-fstab | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status testsvc | grep -q 'State: STARTED'")

    # activation created the boot.d symlink for testsvc
    machine.succeed("test -L /etc/dinit.d/boot.d/testsvc")

    # stopping boot must never happen via activation; sanity check it's still up
    machine.succeed("dinitctl is-started boot")

    machine.shutdown()
  '';
}
