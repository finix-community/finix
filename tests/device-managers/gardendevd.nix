{ pkgs }:
let
  common = import ./common.nix;
  disks = (import ./disk/images.nix) { inherit pkgs; };

  eventScript = pkgs.writeShellScriptBin "device-manager-test-event" ''
    set -eu
    mkdir -p /run/device-manager-test
    device_path="''${DEVPATH:-unknown}"
    device_name="''${device_path##*/}"
    printf '%s %s %s\n' "''${1:-unknown}" "$device_name" "$device_path" \
      >> /run/device-manager-test/events
  '';

  eventRulesText = ''
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="vd*", RUN+="${eventScript}/bin/device-manager-test-event add"
    ACTION=="remove", SUBSYSTEM=="block", KERNEL=="vd*", RUN+="${eventScript}/bin/device-manager-test-event remove"
    ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{FINIT_TEST_DISK_TAG}="disk-tag"
    ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", IMPORT{parent}="FINIT_TEST_DISK_TAG"
  '';
  eventRuleFile = pkgs.writeText "99-finix-device-manager-test.rules" eventRulesText;
  eventRules = pkgs.runCommand "finix-device-manager-test-gardendevd-rules" { } ''
    mkdir -p "$out/etc/udev/rules.d"
    cp ${eventRuleFile} "$out/etc/udev/rules.d/99-finix-device-manager-test.rules"
  '';
in
common {
  backend = {
    name = "gardendevd";
    serviceName = "gardendevd";
    configServiceName = "gardendevd";
    configBinary = "gardendevctl";
    readyCondition = "service/gardendevd/ready";
    coldplugCondition = "run/gardendevctl:2/success";
    configCheck = "settle -t 30";
    reloadCommand = "gardendevctl control --reload";
    inherit disks eventScript;
    module =
      { ... }:
      {
        services.gardendevd.enable = true;
        services.udev.packages = [ eventRules ];
        environment.systemPackages = [ eventScript ];
      };
    backendScript = ''
      UDEV_DB = {}


      def backend_validate(machine):
          machine.succeed(CONFIG_CHECK)
          machine.succeed("gardendevctl control --ping")
          machine.succeed("test -s /run/gardendevd.pid")
          database = machine.succeed("gardendevctl info -e")
          assert "E: ACTION=add" in database, database


      def _event_name(record):
          return record["device"].rsplit("/", 1)[-1]


      def _assert_event(machine, action, event_name, event_log, previous, timeout):
          if COLDPLUG and previous is None:
              return
          if previous is None:
              machine.wait_until_succeeds(
                  f"grep -Eq '^{action} {event_name} /devices/.+' {event_log}",
                  timeout=timeout,
              )
          else:
              wait_for_new_event(machine, action, event_name, event_log, previous, timeout)


      def _udev_db_path(machine, name):
          dev = machine.succeed(f"cat /sys/class/block/{name}/dev").strip()
          return f"/run/udev/data/b{dev}"


      def _assert_udev_db(machine, name, timeout):
          path = _udev_db_path(machine, name)
          UDEV_DB[name] = path
          machine.wait_until_succeeds(
              f"grep -q '^E:ACTION=add$' {path}", timeout=timeout
          )


      def _assert_udev_db_removed(name, timeout):
          assert name in UDEV_DB, f"no udev database path recorded for {name}"
          machine.wait_until_succeeds(f"test ! -e {UDEV_DB[name]}", timeout=timeout)


      def _disk_tag(machine, device):
          return machine.succeed(
              f"gardendevctl info -q property --property=FINIT_TEST_DISK_TAG --value {device}"
          ).strip()


      def _assert_parent_import(machine, record, timeout):
          disk_name = record["disk"].rsplit("/", 1)[-1]
          partition_name = _event_name(record)

          tag = _disk_tag(machine, record["disk"])
          assert tag == "disk-tag", (
              f"test rule did not tag the disk ({disk_name}, {tag!r}); a malformed "
              "rule line is dropped whole, check for 'unknown key' with "
              "'gardendevctl -v debug test <device>'"
          )

          machine.succeed(
              f"gardendevctl trigger -c add -s block -y {partition_name} -w",
              timeout=timeout,
          )

          tag = _disk_tag(machine, record["device"])
          assert tag == "disk-tag", (partition_name, tag)


      def backend_add_check(machine, record, event_log, previous, timeout):
          disk_name = record["disk"].rsplit("/", 1)[-1]
          serial = record["metadata"]["serial"]
          _assert_event(
              machine,
              "add",
              disk_name,
              event_log,
              None if previous is None else previous["disk"],
              timeout,
          )
          assert_device_mode(machine, record["disk"], DISK_GID)
          assert_link(
              machine,
              f"/dev/disk/by-id/virtio-{serial}",
              record["disk"],
              timeout,
          )
          _assert_udev_db(machine, disk_name, timeout)

          metadata = record["metadata"]
          if metadata["label"] is not None:
              assert_link(
                  machine,
                  f"/dev/disk/by-label/{metadata['label']}",
                  record["device"],
                  timeout,
              )
          if metadata["uuid"] is not None:
              assert_link(
                  machine,
                  f"/dev/disk/by-uuid/{metadata['uuid']}",
                  record["device"],
                  timeout,
              )
          if metadata["partitioned"]:
              partition_name = _event_name(record)
              _assert_event(
                  machine,
                  "add",
                  partition_name,
                  event_log,
                  None if previous is None else previous["partition"],
                  timeout,
              )
              assert_device_mode(machine, record["device"], DISK_GID)
              assert_link(
                  machine,
                  f"/dev/disk/by-id/virtio-{serial}-part{metadata['partitionNumber']}",
                  record["device"],
                  timeout,
              )
              assert_link(
                  machine,
                  f"/dev/disk/by-partlabel/{metadata['partitionLabel']}",
                  record["device"],
                  timeout,
              )
              assert_link(
                  machine,
                  f"/dev/disk/by-partuuid/{metadata['partitionUuid']}",
                  record["device"],
                  timeout,
              )
              _assert_udev_db(machine, partition_name, timeout)
              _assert_parent_import(machine, record, timeout)


      def backend_remove_check(machine, record, event_log, previous, timeout):
          disk_name = record["disk"].rsplit("/", 1)[-1]
          serial = record["metadata"]["serial"]
          _assert_event(
              machine,
              "remove",
              disk_name,
              event_log,
              previous["disk"],
              timeout,
          )
          assert_link_absent(machine, f"/dev/disk/by-id/virtio-{serial}", timeout)
          _assert_udev_db_removed(disk_name, timeout)

          metadata = record["metadata"]
          if metadata["label"] is not None:
              assert_link_absent(machine, f"/dev/disk/by-label/{metadata['label']}", timeout)
          if metadata["uuid"] is not None:
              assert_link_absent(machine, f"/dev/disk/by-uuid/{metadata['uuid']}", timeout)
          if metadata["partitioned"]:
              partition_name = _event_name(record)
              _assert_event(
                  machine,
                  "remove",
                  partition_name,
                  event_log,
                  previous["partition"],
                  timeout,
              )
              assert_link_absent(
                  machine,
                  f"/dev/disk/by-id/virtio-{serial}-part{metadata['partitionNumber']}",
                  timeout,
              )
              assert_link_absent(
                  machine,
                  f"/dev/disk/by-partlabel/{metadata['partitionLabel']}",
                  timeout,
              )
              assert_link_absent(
                  machine,
                  f"/dev/disk/by-partuuid/{metadata['partitionUuid']}",
                  timeout,
              )
              _assert_udev_db_removed(partition_name, timeout)
    '';
  };
}
