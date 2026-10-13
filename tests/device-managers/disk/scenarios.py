"""Shared disk scenarios for device-manager VM tests"""

import shutil


def _filesystem_device(machine, disk, metadata, timeout):
    if metadata["partitioned"]:
        return wait_for_partition(machine, disk, 1, timeout=timeout)
    return disk


def coldplug_filesystems(machine, disks, order, event_log, add_check, timeout):
    records = {}
    for name in order:
        metadata = disks[name]
        disk = wait_for_serial(machine, metadata["serial"], timeout=timeout)
        filesystem = _filesystem_device(machine, disk, metadata, timeout)
        assert_filesystem_metadata(machine, filesystem, metadata)
        record = {"name": name, "metadata": metadata, "disk": disk, "device": filesystem}
        records[name] = record
        add_check(machine, record, event_log, None, timeout)
    return records


def _mount_write_read(machine, record, mountpoint, marker, expected=None):
    machine.succeed(f"mkdir -p {mountpoint}")
    machine.succeed(f"mount {record['device']} {mountpoint}")
    if expected is not None:
        machine.succeed(f"grep -Fx {expected} {mountpoint}/finix-hotplug-test")
    machine.succeed(f"printf '%s\\n' {marker} > {mountpoint}/finix-hotplug-test")
    machine.succeed(f"grep -Fx {marker} {mountpoint}/finix-hotplug-test")
    machine.succeed(f"umount {mountpoint}")


def hotplug_filesystems(
    machine,
    disks,
    order,
    event_log,
    add_check,
    remove_check,
    timeout,
):
    for name in order:
        metadata = disks[name]
        image = machine.shared_dir / f"{metadata['serial']}.img"
        shutil.copyfile(metadata["image"], image)

        machine.hotplug_disk(image, metadata["serial"])
        disk = wait_for_serial(machine, metadata["serial"], timeout=timeout)
        filesystem = _filesystem_device(machine, disk, metadata, timeout)
        record = {"name": name, "metadata": metadata, "disk": disk, "device": filesystem}
        add_check(machine, record, event_log, None, timeout)
        assert_filesystem_metadata(machine, filesystem, metadata)

        if metadata["fsType"] is not None:
            mountpoint = f"/run/device-manager-test/{metadata['serial']}"
            _mount_write_read(
                machine,
                record,
                mountpoint,
                f"{metadata['serial']}-initial",
            )

        disk_name = disk.rsplit("/", 1)[-1]
        remove_events = {
            "disk": event_count(machine, "remove", disk_name, event_log),
            "partition": (
                event_count(machine, "remove", filesystem.rsplit("/", 1)[-1], event_log)
                if metadata["partitioned"]
                else None
            ),
        }
        machine.unplug_disk(metadata["serial"])
        wait_for_absence(machine, disk, timeout)
        if metadata["partitioned"]:
            wait_for_absence(machine, filesystem, timeout)
        remove_check(machine, record, event_log, remove_events, timeout)

        readd_events = {
            "disk": event_count(machine, "add", disk_name, event_log),
            "partition": (
                event_count(machine, "add", filesystem.rsplit("/", 1)[-1], event_log)
                if metadata["partitioned"]
                else None
            ),
        }
        machine.hotplug_disk(image, metadata["serial"])
        disk = wait_for_serial(machine, metadata["serial"], timeout=timeout)
        filesystem = _filesystem_device(machine, disk, metadata, timeout)
        record = {"name": name, "metadata": metadata, "disk": disk, "device": filesystem}
        add_check(machine, record, event_log, readd_events, timeout)
        assert_filesystem_metadata(machine, filesystem, metadata)

        if metadata["fsType"] is not None:
            _mount_write_read(
                machine,
                record,
                mountpoint,
                f"{metadata['serial']}-readd",
                expected=f"{metadata['serial']}-initial",
            )

        remove_events = {
            "disk": event_count(machine, "remove", disk_name, event_log),
            "partition": (
                event_count(machine, "remove", filesystem.rsplit("/", 1)[-1], event_log)
                if metadata["partitioned"]
                else None
            ),
        }
        machine.unplug_disk(metadata["serial"])
        wait_for_absence(machine, disk, timeout)
        if metadata["partitioned"]:
            wait_for_absence(machine, filesystem, timeout)
        remove_check(machine, record, event_log, remove_events, timeout)
