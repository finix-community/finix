{ pkgs }:
let
  common = import ./common.nix;
  disks = (import ./disk/images.nix) { inherit pkgs; };
  eventScript = pkgs.writeShellScriptBin "device-manager-test-event" ''
    set -eu
    mkdir -p /run/device-manager-test
    printf '%s %s %s\n' \
      "''${1:-unknown}" "''${2:-unknown}" "''${3:-unknown}" \
      >> /run/device-manager-test/events
  '';
in
common {
  backend = {
    name = "keventd";
    serviceName = "keventd";
    configServiceName = "keventd";
    configBinary = "keventd";
    readyCondition = "service/keventd/ready";
    coldplugCondition = "pid/keventd";
    configCheck = "-S -t 30";
    reloadCommand = "initctl reload keventd";
    inherit disks eventScript;
    module =
      { eventScript, ... }:
      let
        eventRulesText = ''
          ACTION=="add", SUBSYSTEM=="block", KERNEL=="vd*", RUN+="${eventScript}/bin/device-manager-test-event add %k %p"
          ACTION=="remove", SUBSYSTEM=="block", KERNEL=="vd*", RUN+="${eventScript}/bin/device-manager-test-event remove %k %p"
        '';
        eventRuleFile = pkgs.writeText "99-finix-device-manager-test.rules" eventRulesText;
        eventRules = pkgs.runCommand "finix-device-manager-test-keventd-rules" { } ''
          mkdir -p "$out/etc/udev/rules.d"
          cp ${eventRuleFile} "$out/etc/udev/rules.d/99-finix-device-manager-test.rules"
        '';
      in
      {
        services.keventd.enable = true;
        services.udev.packages = [ eventRules ];
      };
    backendScript = ''
      def backend_validate(machine):
          machine.succeed(CONFIG_CHECK)


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
    '';
  };
}
