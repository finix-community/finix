"""Small backend-neutral helpers embedded into VM test scripts"""


def wait_for_device(machine, device, timeout=30):
    machine.wait_until_succeeds(f"test -b {device}", timeout=timeout)


def wait_for_link(machine, link, timeout=30):
    machine.wait_until_succeeds(f"test -L {link}", timeout=timeout)


def resolved_link(machine, link):
    return machine.succeed(f"readlink -f {link}").strip()


def assert_device_mode(machine, device, uid=0, gid=6, mode="660"):
    actual = machine.succeed(f"stat -c '%u:%g:%a' {device}").strip()
    expected = f"{uid}:{gid}:{mode}"
    assert actual == expected, f"unexpected {device} metadata: {actual}, expected {expected}"


def assert_link(machine, link, device):
    wait_for_link(machine, link)
    assert resolved_link(machine, link) == device, (
        f"{link} resolves to {resolved_link(machine, link)}, expected {device}"
    )
