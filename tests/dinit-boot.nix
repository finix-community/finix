# test that the system boots successfully with dinit as PID 1
#
# verifies the dinit module generates a bootable service set:
# boot target comes up and activation creates the target-directory links.
{
  name = "dinit-boot";

  nodes.machine =
    { pkgs, lib, ... }:
    {
      # all finix modules (incl. dinit) are already imported by the test harness
      system.init = "dinit";
      # Stage 1 uses Finit/udev while stage 2 uses Dinit/mdevd.
      boot.initrd.deviceManager = "udev";

      services.mdevd.enable = true;
      # The VM's serial console is ttyS0, while the normal getty set is tty1-6.
      # Keep this graph test independent of console-specific getty behavior.
      services.getty.enable = false;

      environment.systemPackages = [ pkgs.python3 ];
      environment.etc."dinit-test-manifest".text = ''
        {
          "services": {"existing": {"startOnSwitch": false}},
          "targetServices": ["boot", "filesystem.target", "local.target", "login.target", "network.target"],
          "targetDirectories": ["boot.d", "filesystem.d", "local.d", "login.d", "network.d"]
        }
      '';
      environment.etc."dinit-test-dinitctl".source = pkgs.writeShellScript "dinit-test-dinitctl" ''
        case "$1" in
          list)
            echo "[  +  ] existing"
            ;;
          reload)
            echo "reload failed" >&2
            exit 1
            ;;
          *)
            ;;
        esac
      '';

      # a trivial service that must come up as part of the boot target
      dinit.services.testsvc = {
        command = "${pkgs.coreutils}/bin/sleep infinity";
        targets = [ "local" ];
        restart = true;
      };

      specialisation = {
        move-testsvc = {
          dinit.services.testsvc.targets = lib.mkForce [ "network" ];
        };

        remove-testsvc = {
          dinit.services.testsvc.enable = false;
        };

        broken-service = {
          dinit.services.broken = {
            type = "scripted";
            command = "${pkgs.coreutils}/bin/false";
            targets = [ "local" ];
          };
        };

        custom-init = {
          boot.init = pkgs.writeShellScript "custom-dinit-init" ''
            exit 0
          '';
        };
      };
    };

  nodes.finit =
    { ... }:
    {
      system.init = "finit";
      services.mdevd.enable = true;
    };

  testScript = ''
    machine.start()
    finit.start()

    # boot target and its boot.d dependencies should be up
    machine.wait_until_succeeds("dinitctl status boot | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status mount-fstab | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status tmpfiles-setup | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status sysctl | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status remount-nix-store | grep -q 'State: STARTED'")
    machine.wait_until_succeeds("dinitctl status suid-sgid-wrappers | grep -q 'State: STARTED'")
    machine.succeed("test -u /run/wrappers/bin/unix_chkpwd")
    machine.wait_until_succeeds("dinitctl status testsvc | grep -q 'State: STARTED'")

    # activation created the local.d symlink for testsvc
    machine.succeed("test -L /etc/dinit.d/local.d/testsvc")

    # the boot graph is made up of explicit target services
    machine.succeed("test -L /etc/dinit.d/boot.d/filesystem.target")
    machine.succeed("test -L /etc/dinit.d/boot.d/local.target")
    machine.succeed("test -L /etc/dinit.d/filesystem.d/mount-fstab")
    machine.succeed("readlink /etc/dinit.d/testsvc | grep -q '^/nix/store/'")
    machine.succeed("test \"$(readlink /etc/dinit.d/local.d/testsvc)\" = ../testsvc")

    # reload failures must be reported by the switch helper
    machine.fail(
      "switch=$(grep -o '/nix/store/[^ ]*-dinit-switch.py' /run/current-system/activate | head -n1); "
      "python3 $switch --dinitctl /etc/dinit-test-dinitctl "
      "--manifest /etc/dinit-test-manifest"
    )

    # boot.init overrides must be used by the Dinit stage-2 wrapper
    machine.succeed(
      "grep -q custom-dinit-init /run/current-system/specialisation/custom-init/init"
    )
    machine.succeed("grep -q '^set -e$' /run/current-system/init")

    move_system = machine.succeed(
      "readlink -f /run/current-system/specialisation/move-testsvc"
    ).strip()
    broken_system = machine.succeed(
      "readlink -f /run/current-system/specialisation/broken-service"
    ).strip()
    remove_system = machine.succeed(
      "readlink -f /run/current-system/specialisation/remove-testsvc"
    ).strip()

    # switching target membership updates links without losing a running service
    machine.succeed(f"{move_system}/bin/switch-to-configuration test")
    machine.succeed("test ! -e /etc/dinit.d/local.d/testsvc")
    machine.succeed("test -L /etc/dinit.d/network.d/testsvc")
    machine.succeed("dinitctl is-started testsvc")

    # service-start failures must make switching fail
    machine.fail(f"{broken_system}/bin/switch-to-configuration test")

    # removing a service unloads it and removes all target links
    machine.succeed(f"{remove_system}/bin/switch-to-configuration test")
    machine.succeed("test ! -e /etc/dinit.d/network.d/testsvc")
    machine.fail("dinitctl status testsvc")

    # stopping boot must never happen via activation; sanity check it's still up
    machine.succeed("dinitctl is-started boot")

    machine.shutdown()

    finit.wait_for_console_text("entering runlevel 2")
    finit.succeed("test ! -e /etc/dinit.d/boot")
    finit.shutdown()
  '';
}
