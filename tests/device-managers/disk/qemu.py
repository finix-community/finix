"""QEMU disk identity helpers used by the device-manager test scripts"""

import datetime as dt


def _serial_probe(serial):
    return (
        "for serial_path in /sys/block/*/serial; do "
        "[ -r \"$serial_path\" ] || continue; "
        f"[ \"$(cat \"$serial_path\")\" = \"{serial}\" ] || continue; "
        "basename \"$(dirname \"$serial_path\")\"; exit 0; "
        "done; exit 1"
    )


def device_for_serial(machine, serial):
    name = machine.succeed(_serial_probe(serial)).strip()
    assert name.startswith("vd"), f"serial {serial!r} resolved to unexpected block name {name!r}"
    return f"/dev/{name}"


def wait_for_serial(machine, serial, timeout=dt.timedelta(seconds=30)):
    machine.wait_until_succeeds(_serial_probe(serial), timeout=timeout)
    return device_for_serial(machine, serial)


def wait_for_partition(machine, device, number=1, timeout=dt.timedelta(seconds=30)):
    name = device.rsplit("/", 1)[-1]
    partition = f"/dev/{name}{number}"
    sysfs_partition = f"/sys/class/block/{name}/{name}{number}"
    machine.wait_until_succeeds(
        f"test -b {partition} && test -e {sysfs_partition}", timeout=timeout
    )
    return partition


def disk_serials(machine):
    output = machine.succeed(
        "for serial_path in /sys/block/*/serial; do "
        "[ -r \"$serial_path\" ] || continue; "
        "printf '%s %s\\n' \"$(basename \"$(dirname \"$serial_path\")\")\" "
        "\"$(cat \"$serial_path\")\"; "
        "done"
    )
    return dict(line.split(" ", 1) for line in output.splitlines())
