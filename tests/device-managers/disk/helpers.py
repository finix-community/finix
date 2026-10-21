"""Polling and assertion helpers embedded into device-manager VM scripts"""


def wait_for_device(machine, device, timeout):
    machine.wait_until_succeeds(f"test -b {device}", timeout=timeout)


def wait_for_link(machine, link, timeout):
    machine.wait_until_succeeds(f"test -L {link}", timeout=timeout)


def wait_for_absence(machine, path, timeout):
    machine.wait_until_succeeds(
        f"test ! -e {path} && test ! -L {path}", timeout=timeout
    )


def resolved_link(machine, link):
    return machine.succeed(f"readlink -f {link}").strip()


def assert_link(machine, link, device, timeout):
    wait_for_link(machine, link, timeout)
    actual = resolved_link(machine, link)
    assert actual == device, f"{link} resolves to {actual}, expected {device}"


def assert_link_absent(machine, link, timeout):
    wait_for_absence(machine, link, timeout)


def assert_device_mode(machine, device, disk_gid):
    actual = machine.succeed(f"stat -c '%u:%g:%a' {device}").strip()
    expected = f"0:{disk_gid}:660"
    assert actual == expected, (
        f"unexpected {device} metadata: {actual}, expected {expected}"
    )


def assert_filesystem_metadata(machine, device, metadata):
    fs_type = metadata["fsType"]
    if fs_type is None:
        return
    values = machine.succeed(f"blkid --output export {device}").splitlines()
    fields = dict(line.split("=", 1) for line in values if "=" in line)
    assert fields.get("TYPE") == fs_type, (device, fields, metadata)
    if metadata["label"] is not None:
        assert fields.get("LABEL") == metadata["label"], (device, fields, metadata)
    if metadata["uuid"] is not None:
        assert fields.get("UUID") == metadata["uuid"], (device, fields, metadata)


def event_count(machine, action, device_name, event_log):
    output = machine.succeed(
        f"grep -Ec '^{action} {device_name} ' {event_log} || true"
    ).strip()
    return int(output)


def wait_for_new_event(machine, action, device_name, event_log, previous, timeout):
    machine.wait_until_succeeds(
        f"test $(grep -Ec '^{action} {device_name} ' {event_log} || true) "
        f"-ge {previous + 1}",
        timeout=timeout,
    )
