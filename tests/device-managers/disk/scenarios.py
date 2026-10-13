"""Shared disk scenarios for device-manager VM tests"""

def coldplug_filesystems(machine):
    devices = {
        "/dev/vda": {"label": "finix-ext4", "uuid": "11111111-2222-3333-4444-555555555555"},
        "/dev/vdb": {"label": "finix-btrfs", "uuid": "22222222-3333-4444-5555-666666666666"},
        "/dev/vdc": {"label": "FINIXVFAT"},
        "/dev/vdd": {},
    }

    for device in all_boot_disks():
        wait_for_device(machine, device)
        assert_device_mode(machine, device)

    assert_link(machine, "/dev/disk/by-id/vda", "/dev/vda")
    for device, metadata in devices.items():
        label = metadata.get("label")
        if label:
            machine.succeed(f"test -L /dev/disk/by-label/{label}")
        uuid = metadata.get("uuid")
        if uuid:
            machine.succeed(f"test -L /dev/disk/by-uuid/{uuid}")


def event_log_contains_all_disks(machine, event_log):
    for device in all_boot_disks():
        name = device.rsplit("/", 1)[-1]
        machine.wait_until_succeeds(f"grep -Eq '^add {name} ' {event_log}", timeout=30)
