import argparse
import json
import os
import subprocess
import sys


BOOTSTRAP_ENV = "FINIX_DINIT_BOOTSTRAP"


class SwitchError(RuntimeError):
    pass


def run(dinitctl, *args):
    return subprocess.run(
        [dinitctl, *args],
        capture_output=True,
        text=True,
    )


def loaded_services(dinitctl, reserved):
    result = run(dinitctl, "list")
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip()
        raise SwitchError(f"dinitctl list failed: {details}")

    services = set()
    for line in result.stdout.splitlines():
        if not line.startswith("["):
            continue

        try:
            name = line.rsplit("]", 1)[1].strip().split(None, 1)[0]
        except (IndexError, ValueError):
            continue

        if name not in reserved:
            services.add(name)

    return services


def remove_service(dinitctl, name, target_directories):
    print(f"dinit-switch: removing '{name}'", file=sys.stderr)

    failed = False
    stopped = run(dinitctl, "stop", name)
    if report_failure(f"stop '{name}'", stopped):
        failed = True

    unloaded = run(dinitctl, "unload", name)
    if report_failure(f"unload '{name}'", unloaded):
        failed = True

    for directory in target_directories:
        path = f"/etc/dinit.d/{directory}/{name}"
        if os.path.islink(path):
            try:
                os.unlink(path)
            except OSError as error:
                print(
                    f"dinit-switch: removing link '{path}' failed: {error}",
                    file=sys.stderr,
                )
                failed = True

    return not failed


def report_failure(action, result):
    if result.returncode == 0:
        return False

    details = result.stderr.strip() or result.stdout.strip()
    print(
        f"dinit-switch: {action} failed: {details}",
        file=sys.stderr,
    )
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dinitctl", required=True)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()

    with open(args.manifest) as manifest:
        manifest = json.load(manifest)

    desired = manifest["services"]
    target_services = set(manifest["targetServices"])
    target_directories = manifest["targetDirectories"]

    try:
        current = loaded_services(args.dinitctl, target_services)
    except SwitchError as error:
        if os.environ.get(BOOTSTRAP_ENV) == "1":
            print(
                "dinit-switch: dinit is not running yet; deferring service switching",
                file=sys.stderr,
            )
            return 0
        print(f"dinit-switch: {error}", file=sys.stderr)
        return 1

    desired_names = set(desired)
    failed = False

    for name in sorted(target_services):
        if report_failure(f"reload '{name}'", run(args.dinitctl, "reload", name)):
            failed = True

    for name in sorted(current & desired_names):
        if report_failure(f"reload '{name}'", run(args.dinitctl, "reload", name)):
            failed = True

    for name in sorted(current - desired_names):
        if not remove_service(args.dinitctl, name, target_directories):
            failed = True

    for name in sorted(desired_names):
        if desired[name]["startOnSwitch"]:
            print(f"dinit-switch: ensuring '{name}' is started", file=sys.stderr)
            if report_failure(f"start '{name}'", run(args.dinitctl, "start", name)):
                failed = True

    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
