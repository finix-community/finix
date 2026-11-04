"""
Finit-specific Machine class for the finix test driver.

This extends the NixOS test driver's Machine class with finit-specific
methods, replacing systemd-specific functionality.
"""

import datetime as dt
import re
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

from test_driver.duration import Duration, as_timedelta
from test_driver.machine import QemuMachine
from test_driver.machine.qmp import QMPAPIError


class FinitMachine(QemuMachine):
    """Machine with finit-specific methods instead of systemd."""

    def start(self, allow_reboot: bool = False) -> None:
        if not self.booted:
            if self.qmp_client is not None:
                self.qmp_client.close()
            self._hotplug_disks = {}
            self._qmp_uncertain = False
            self._allow_reboot = allow_reboot
        super().start(allow_reboot=allow_reboot)

    def qmp(
        self,
        command: str,
        arguments: dict[str, Any] | None = None,
        timeout: Duration = dt.timedelta(seconds=30),
    ) -> Any:
        if self.qmp_client is None or not self.booted:
            raise RuntimeError("QMP is not ready; start the machine first")
        try:
            return self.qmp_client.send(command, arguments, as_timedelta(timeout))[
                "return"
            ]
        except QMPAPIError:
            raise
        except BaseException:
            self._qmp_uncertain = True
            raise

    def wait_for_qmp_event(
        self,
        event_filter: Callable[[dict[str, Any]], bool],
        timeout: Duration = dt.timedelta(minutes=10),
    ) -> dict[str, Any]:
        """Wait with one overall deadline including unrelated QMP events"""
        if self.qmp_client is None:
            raise RuntimeError("QMP is not ready; start the machine first")
        deadline = time.monotonic() + as_timedelta(timeout).total_seconds()
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Timed out waiting for matching QMP event")
            return self.qmp_client.wait_for_event(
                dt.timedelta(seconds=remaining), event_filter=event_filter
            )

    def hotplug_disk(self, image: str | Path, disk_id: str) -> str:
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,40}", disk_id):
            raise ValueError(f"Invalid disk ID: {disk_id!r}")
        if not self.booted:
            raise RuntimeError("Start the machine before adding disks")
        if disk_id in self._hotplug_disks:
            raise ValueError(f"Disk already managed: {disk_id}")
        if getattr(self, "_qmp_uncertain", False):
            raise RuntimeError("QMP state is uncertain; refusing a disk mutation")
        node = f"finix-{disk_id}"
        state = {
            "node": node,
            "attached": False,
            "deleting": False,
            "uncertain": False,
        }
        self._hotplug_disks[disk_id] = state
        try:
            self.qmp(
                "blockdev-add",
                {
                    "driver": "raw",
                    "node-name": node,
                    "file": {
                        "driver": "file",
                        "filename": str(Path(image).resolve()),
                    },
                },
            )
        except QMPAPIError:
            del self._hotplug_disks[disk_id]
            raise
        except BaseException:
            state["uncertain"] = True
            raise

        try:
            self.qmp(
                "device_add",
                {
                    "driver": "virtio-blk-pci",
                    "drive": node,
                    "id": disk_id,
                    "serial": disk_id,
                },
            )
        except QMPAPIError as original_error:
            try:
                self.qmp("blockdev-del", {"node-name": node})
            except QMPAPIError:
                pass
            except BaseException:
                state["uncertain"] = True
            else:
                del self._hotplug_disks[disk_id]
            raise original_error
        except BaseException:
            state["uncertain"] = True
            raise
        state["attached"] = True
        return disk_id

    def unplug_disk(
        self, disk_id: str, timeout: Duration = dt.timedelta(seconds=30)
    ) -> None:
        qmp_client = self.qmp_client
        if qmp_client is None:
            raise RuntimeError("QMP is not ready; start the machine first")
        state = self._hotplug_disks[disk_id]
        if state["uncertain"] or getattr(self, "_qmp_uncertain", False):
            raise RuntimeError(
                f"QMP state for disk {disk_id!r} is uncertain; refusing mutation"
            )
        if state["attached"]:
            if not state["deleting"]:
                qmp_client.discard_events(
                    lambda event: (
                        event.get("event") == "DEVICE_DELETED"
                        and event.get("data", {}).get("device") == disk_id
                    )
                )
                self.qmp("device_del", {"id": disk_id}, timeout=timeout)
                state["deleting"] = True
            try:
                self.wait_for_qmp_event(
                    lambda event: (
                        event.get("event") == "DEVICE_DELETED"
                        and event.get("data", {}).get("device") == disk_id
                    ),
                    timeout=timeout,
                )
            except BaseException:
                state["uncertain"] = True
                raise
            state["attached"] = False
        try:
            self.qmp("blockdev-del", {"node-name": state["node"]}, timeout=timeout)
        except QMPAPIError:
            raise
        except BaseException:
            state["uncertain"] = True
            raise
        del self._hotplug_disks[disk_id]

    def cleanup_hotplug_disks(
        self, timeout: Duration = dt.timedelta(seconds=30)
    ) -> None:
        first_error: BaseException | None = None
        for disk_id in list(self._hotplug_disks):
            try:
                self.unplug_disk(disk_id, timeout=timeout)
            except BaseException as error:
                if first_error is None:
                    first_error = error
        if first_error is not None:
            raise first_error

    def wait_for_condition(
        self, condition: str, timeout: Duration = dt.timedelta(minutes=15)
    ) -> None:
        """
        Wait for a finit condition to be set.

        Conditions are in finit format, e.g.:
        - service/foo/running
        - task/foo/success
        - net/eth0/up

        Args:
            condition: The finit condition to wait for
            timeout: Maximum time to wait, as a datetime.timedelta
        """
        with self.nested(f"waiting for finit condition '{condition}'"):
            self.wait_until_succeeds(f"initctl cond get {condition}", timeout=timeout)

    def wait_for_runlevel(
        self, level: int, timeout: Duration = dt.timedelta(minutes=15)
    ) -> None:
        """
        Wait for finit to reach a specific runlevel.

        Args:
            level: The runlevel number (0-9, S)
            timeout: Maximum time to wait, as a datetime.timedelta
        """
        with self.nested(f"waiting for runlevel {level}"):
            self.wait_for_console_text(f"entering runlevel {level}", timeout=timeout)

    def initctl(self, cmd: str) -> tuple[int, str]:
        """
        Run an initctl command.

        Args:
            cmd: The initctl subcommand and arguments

        Returns:
            Tuple of (exit_code, output)
        """
        return self.execute(f"initctl {cmd}")

    def wait_for_service(
        self, service: str, timeout: Duration = dt.timedelta(minutes=15)
    ) -> None:
        """
        Wait for a finit service to be running.

        Args:
            service: The service name
            timeout: Maximum time to wait, as a datetime.timedelta
        """
        self.wait_for_condition(f"service/{service}/running", timeout=timeout)

    def wait_for_task(
        self, task: str, timeout: Duration = dt.timedelta(minutes=15)
    ) -> None:
        """
        Wait for a finit task to complete successfully.

        Args:
            task: The task name
            timeout: Maximum time to wait, as a datetime.timedelta
        """
        self.wait_for_condition(f"task/{task}/success", timeout=timeout)

    def start_service(self, service: str) -> tuple[int, str]:
        """
        Start a finit service.

        Args:
            service: The service name

        Returns:
            Tuple of (exit_code, output)
        """
        return self.initctl(f"start {service}")

    def stop_service(self, service: str) -> tuple[int, str]:
        """
        Stop a finit service.

        Args:
            service: The service name

        Returns:
            Tuple of (exit_code, output)
        """
        return self.initctl(f"stop {service}")

    def reload_service(self, service: str) -> tuple[int, str]:
        """
        Reload a finit service configuration.

        Args:
            service: The service name

        Returns:
            Tuple of (exit_code, output)
        """
        return self.initctl(f"reload {service}")

    def get_service_status(self, service: str) -> tuple[int, str]:
        """
        Get the status of a finit service.

        Args:
            service: The service name

        Returns:
            Tuple of (exit_code, output)
        """
        return self.initctl(f"status {service}")

    # override systemd-specific methods to prevent accidental use
    def wait_for_unit(
        self,
        unit: str,
        user: str | None = None,
        timeout: Duration = dt.timedelta(minutes=15),
    ) -> None:
        """Raises error - use wait_for_service() or wait_for_condition() instead."""
        raise NotImplementedError(
            f"wait_for_unit('{unit}') is systemd-specific. "
            f"Use wait_for_service('{unit}') or wait_for_condition() instead."
        )

    def systemctl(self, q: str, user: str | None = None) -> tuple[int, str]:
        """Raises error - use initctl() instead."""
        raise NotImplementedError(
            "systemctl() is systemd-specific. Use initctl() instead."
        )

    def get_unit_info(self, unit: str, user: str | None = None) -> dict[str, str]:
        """Raises error - use get_service_status() instead."""
        raise NotImplementedError(
            f"get_unit_info('{unit}') is systemd-specific. "
            f"Use get_service_status('{unit}') instead."
        )
