{ pkgs }:
let
  common = import ./common.nix;
  disks = (import ./disk/images.nix) { inherit pkgs; };
  eventScript = pkgs.writeShellScript "device-manager-test-event" ''
    set -eu
    mkdir -p /run/device-manager-test
    printf '%s %s %s\n' "''${ACTION:-unknown}" "''${MDEV:-unknown}" "''${DEVPATH:-unknown}" \
      >> /run/device-manager-test/events
  '';
in
common {
  backend = {
    name = "mdevd";
    serviceName = "mdevd";
    readyCondition = "service/mdevd/ready";
    coldplugCondition = "run/coldplug/success";
    configCheck = "-N -f /etc/mdev.conf";
    inherit disks eventScript;
    module =
      { eventScript, ... }:
      {
        services.mdevd.enable = true;
        services.mdevd.coldplugRules = ''
          -SUBSYSTEM=block;vd[a-z]+[0-9]* 0:0 660 */etc/device-manager-test-event
        '';
        services.mdevd.hotplugRules = ''
          -SUBSYSTEM=block;vd[a-z]+[0-9]* 0:0 660 */etc/device-manager-test-event
        '';
        services.mdevd.nlgroups = 4;

        environment.etc."device-manager-test-event".source = eventScript;
        boot.initrd.contents = [
          {
            source = eventScript;
            target = "/etc/device-manager-test-event";
          }
        ];
      };
    backendScript = ''
      def backend_validate(machine):
          machine.succeed(CONFIG_CHECK)


      def _event_name(record):
          return record["device"].rsplit("/", 1)[-1]


      def _assert_event(machine, action, event_name, event_log, previous, timeout):
          if previous is None:
              machine.wait_until_succeeds(
                  f"grep -Eq '^{action} {event_name} /devices/.+' {event_log}",
                  timeout=timeout,
              )
          else:
              wait_for_new_event(machine, action, event_name, event_log, previous, timeout)


      def backend_add_check(machine, record, event_log, previous, timeout):
          disk_name = record["disk"].rsplit("/", 1)[-1]
          _assert_event(
              machine,
              "add",
              disk_name,
              event_log,
              None if previous is None else previous["disk"],
              timeout,
          )
          assert_device_mode(machine, record["disk"], DISK_GID)
          assert_link(machine, f"/dev/disk/by-id/{disk_name}", record["disk"], timeout)
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
          if record["metadata"]["partitioned"]:
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
                  f"/dev/disk/by-id/{partition_name}",
                  record["device"],
                  timeout,
              )


      def backend_remove_check(machine, record, event_log, previous, timeout):
          disk_name = record["disk"].rsplit("/", 1)[-1]
          _assert_event(
              machine,
              "remove",
              disk_name,
              event_log,
              previous["disk"],
              timeout,
          )
          assert_link_absent(machine, f"/dev/disk/by-id/{disk_name}", timeout)
          metadata = record["metadata"]
          if metadata["label"] is not None:
              assert_link_absent(machine, f"/dev/disk/by-label/{metadata['label']}", timeout)
          if metadata["uuid"] is not None:
              assert_link_absent(machine, f"/dev/disk/by-uuid/{metadata['uuid']}", timeout)
          if record["metadata"]["partitioned"]:
              partition_name = _event_name(record)
              _assert_event(
                  machine,
                  "remove",
                  partition_name,
                  event_log,
                  previous["partition"],
                  timeout,
              )
              assert_link_absent(machine, f"/dev/disk/by-id/{partition_name}", timeout)
    '';
  };
}
