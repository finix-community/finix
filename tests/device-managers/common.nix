# Shared device-manager VM test factory
{
  backend,
  extraNodeConfig ? { },
}:
let
  inherit (backend) name serviceName readyCondition coldplugCondition configCheck module;
  deviceManagerModule =
    { config, lib, pkgs, ... }:
    let
      eventScript = pkgs.writeShellScript "device-manager-test-event" ''
        set -eu
        mkdir -p /run/device-manager-test
        printf '%s %s %s\n' "''${ACTION:-unknown}" "''${MDEV:-unknown}" "''${DEVPATH:-unknown}" \
          >> /run/device-manager-test/events
      '';

      disks = import ./disk/images.nix { inherit pkgs; };
    in
    {
      imports = [ (module { inherit eventScript; }) ];

      services.getty.enable = true;

      boot.kernelModules = [ "loop" ];
      boot.initrd.kernelModules = [ "loop" ];
      boot.kernelParams = [ "udev.log_priority=debug" ];

      environment.systemPackages = with pkgs; [
        e2fsprogs
        util-linux
      ];

      environment.etc."device-manager-test-event".source = eventScript;

      boot.initrd.contents = [
        {
          source = eventScript;
          target = "/etc/device-manager-test-event";
        }
      ];

      finit.tmpfiles.rules = [
        "d /run/device-manager-test 0755 root root -"
      ];

      virtualisation.qemu.extraArgs = lib.concatMap (disk: [
        "-drive"
        "if=virtio,format=raw,readonly=on,file=${disk.image}"
      ]) (builtins.attrValues disks);

      assertions = [
        {
          assertion = config.services.${serviceName}.enable;
          message = "device-manager test backend '${name}' must enable ${serviceName}";
        }
        {
          assertion =
            !config.services.udev.enable
            && !config.services.keventd.enable
            && !config.services.gardendevd.enable;
          message = "device-manager test must run exactly one device manager";
        }
      ];
    };

  diskGid = backend.diskGid or 6;

  testScript =
    { nodes }:
    let
      managerPackage = toString nodes.machine.config.services.${serviceName}.package;
    in
    ''
      import json
      ${builtins.readFile ./disk/helpers.py}
      ${builtins.readFile ./disk/qemu.py}
      ${builtins.readFile ./disk/scenarios.py}

      DISK_GID = ${toString diskGid}
      CONFIG_CHECK = ${builtins.toJSON "${managerPackage}/bin/${serviceName} ${configCheck}"}
      EVENT_LOG = "/run/device-manager-test/events"
      LABEL = "finix-ext4"
      UUID = "11111111-2222-3333-4444-555555555555"

      def service_status(name):
          return json.loads(machine.succeed(f"initctl -j status {name}"))

      def assert_device_metadata(device, target, verify_target=False):
          stat = machine.succeed(f"stat -c '%u:%g:%a' {device}").strip()
          assert stat == f"0:{DISK_GID}:660", f"unexpected {device} metadata: {stat}"
          link_stat = machine.succeed(f"stat -c '%u:%g:%a' {target}").strip()
          assert link_stat == "0:0:777", f"unexpected symlink metadata: {link_stat}"
          if verify_target:
              assert_link(machine, target, device)

      machine.start()
      machine.wait_for_console_text("finix - stage 1", timeout=180)
      machine.wait_for_console_text("finix - stage 2", timeout=180)
      machine.wait_for_console_text("entering runlevel 2", timeout=180)

      with subtest("mdevd startup and readiness"):
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${readyCondition}", timeout=30
          )
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${coldplugCondition}", timeout=30
          )
          manager = service_status("${serviceName}")
          assert manager["status"] == "running", manager
          assert manager["pid"] > 1, manager
          machine.succeed("test -e /run/finit/cond/${readyCondition}")
          machine.succeed(CONFIG_CHECK)

      with subtest("coldplug creates filesystem-specific disk links"):
          coldplug_filesystems(machine)
          machine.wait_until_succeeds(
              "test -b /dev/vda && test -L /dev/disk/by-id/vda && "
              "test -L /dev/disk/by-label/finix-ext4 && "
              "test -L /dev/disk/by-uuid/11111111-2222-3333-4444-555555555555",
              timeout=30,
          )
          assert_device_metadata("/dev/vda", "/dev/disk/by-id/vda", True)
          assert_device_metadata("/dev/vda", f"/dev/disk/by-label/{LABEL}")
          assert_device_metadata("/dev/vda", f"/dev/disk/by-uuid/{UUID}")

          for device, label in (("/dev/vdb", "finix-btrfs"), ("/dev/vdc", "FINIXVFAT")):
              machine.wait_until_succeeds(
                  f"test -b {device} && test -L /dev/disk/by-label/{label}", timeout=30
              )
              assert_device_metadata(device, f"/dev/disk/by-label/{label}")

          machine.succeed("test -b /dev/vdd && test ! -e /dev/disk/by-label/finix-raw")

      with subtest("device-manager isolation"):
          for service in ("udevd", "keventd", "gardendevd"):
              machine.succeed(f"test ! -e /run/finit/cond/service/{service}/ready")
          machine.succeed("kill -0 1")

      with subtest("reload keeps the daemon alive"):
          before = service_status("${serviceName}")
          machine.succeed("initctl reload ${serviceName}")
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${readyCondition}", timeout=30
          )
          after = service_status("${serviceName}")
          assert after["status"] == "running", after
          assert after["pid"] == before["pid"], (before, after)
          machine.succeed(CONFIG_CHECK)

      with subtest("coldplug processes every QEMU disk event"):
          event_log_contains_all_disks(machine, EVENT_LOG)

      with subtest("shutdown"):
          machine.shutdown()
    '';
in
{
  name = "device-managers.${name}";
  nodes.machine = {
    imports = [
      deviceManagerModule
      extraNodeConfig
    ];
  };
  inherit testScript;
}
