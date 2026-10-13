"""QEMU disk layout used by the current Finix VM harness"""


def virtio_device(index):
    return f"/dev/vd{chr(ord('a') + index)}"


def all_boot_disks():
    return [virtio_device(index) for index in range(4)]


def assert_boot_disks(machine):
    for device in all_boot_disks():
        machine.succeed(f"test -b {device}")
