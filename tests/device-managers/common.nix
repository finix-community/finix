# Shared device-manager VM test factory
{
  backend,
  extraNodeConfig ? { },
}:
let
  inherit (backend) name serviceName readyCondition coldplugCondition configCheck module;
  deviceManagerModule =
    { config, pkgs, ... }:
    let
      eventScript = pkgs.writeShellScript "device-manager-test-event" ''
        set -eu
        mkdir -p /run/device-manager-test
        printf '%s %s %s\n' "''${ACTION:-unknown}" "''${MDEV:-unknown}" "''${DEVPATH:-unknown}" \
          >> /run/device-manager-test/events
      '';

      coldplugDisk = pkgs.runCommand "device-manager-coldplug-disk.img"
        {
          nativeBuildInputs = [ pkgs.coreutils pkgs.e2fsprogs ];
        }
        ''
          truncate -s 32M "$out"
          mkfs.ext4 -q -F -L finix-coldplug \
            -U 11111111-2222-3333-4444-555555555555 "$out"
        '';
    in
    {
      imports = [ (module { inherit eventScript coldplugDisk; }) ];

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

      virtualisation.qemu.extraArgs = [
        "-drive"
        "if=virtio,format=raw,readonly=on,file=${coldplugDisk}"
      ];

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

      DISK_GID = ${toString diskGid}
      CONFIG_CHECK = ${builtins.toJSON "${managerPackage}/bin/${serviceName} ${configCheck}"}
      EVENT_LOG = "/run/device-manager-test/events"
      LABEL = "finix-coldplug"
      UUID = "11111111-2222-3333-4444-555555555555"

      def service_status(name):
          return json.loads(machine.succeed(f"initctl -j status {name}"))

      def wait_for_link(path, target):
          machine.wait_until_succeeds(f"test -L {path} && test \\\"$(readlink {path})\\\" = \\\"{target}\\\"", timeout=30)

      def assert_device_metadata(device, target):
          stat = machine.succeed(f"stat -c '%u:%g:%a' {device}").strip()
          assert stat == f"0:{DISK_GID}:660", f"unexpected {device} metadata: {stat}"
          link_stat = machine.succeed(f"stat -c '%u:%g:%a' {target}").strip()
          assert link_stat == "0:0:777", f"unexpected symlink metadata: {link_stat}"
          wait_for_link(target, "../../" + device.rsplit("/", 1)[-1])

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

      with subtest("coldplug creates rule-owned disk links"):
          machine.wait_until_succeeds(
              "test -b /dev/vda && test -L /dev/disk/by-id/vda && "
              "test -L /dev/disk/by-label/finix-coldplug && "
              "test -L /dev/disk/by-uuid/11111111-2222-3333-4444-555555555555",
              timeout=30,
          )
          assert_device_metadata("/dev/vda", "/dev/disk/by-id/vda")
          assert_device_metadata("/dev/vda", f"/dev/disk/by-label/{LABEL}")
          assert_device_metadata("/dev/vda", f"/dev/disk/by-uuid/{UUID}")

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

      with subtest("loop-device add/remove events and rules"):
          image = "/run/device-manager-test/hotplug.img"
          label = "finix-hotplug"
          uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
          machine.succeed(
              "truncate -s 32M {image} && "
              "mkfs.ext4 -q -F -L {label} -U {uuid} {image}".format(
                  image=image, label=label, uuid=uuid
              )
          )

          for cycle in range(3):
              loop = machine.succeed(
                  f"losetup --find --show {image}"
              ).strip()
              device = loop.rsplit("/", 1)[-1]
              assert device.startswith("loop"), loop
              machine.wait_until_succeeds(f"test -b {loop}", timeout=30)
              machine.wait_until_succeeds(
                  f"test -L /dev/disk/by-label/{label} && "
                  f"test -L /dev/disk/by-uuid/{uuid}",
                  timeout=30,
              )
              machine.wait_until_succeeds(
                  f"grep -Eq '^add {device} ' {EVENT_LOG}", timeout=30
              )
              assert_device_metadata(loop, f"/dev/disk/by-label/{label}")
              assert_device_metadata(loop, f"/dev/disk/by-uuid/{uuid}")

              machine.succeed(f"losetup --detach {loop}")
              machine.wait_until_succeeds(
                  f"! losetup --list --noheadings --output NAME,BACK-FILE | "
                  f"grep -F {image}", timeout=30
              )
              machine.wait_until_succeeds(
                  f"test ! -e /sys/block/{device}/loop/backing_file", timeout=30
              )

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
