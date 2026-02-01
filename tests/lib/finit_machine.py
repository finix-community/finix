"""
Finit-specific Machine class for the finix test driver.

This extends the NixOS test driver's Machine class with finit-specific
methods, replacing systemd-specific functionality.
"""

from test_driver.machine import Machine


class FinitMachine(Machine):
    """Machine with finit-specific methods instead of systemd."""

    def wait_for_condition(self, condition: str, timeout: int = 900) -> None:
        """
        Wait for a finit condition to be set.

        Conditions are in finit format, e.g.:
        - service/foo/running
        - task/foo/success
        - net/eth0/up

        Args:
            condition: The finit condition to wait for
            timeout: Maximum time to wait in seconds
        """
        with self.nested(f"waiting for finit condition '{condition}'"):
            self.wait_until_succeeds(f"initctl cond get {condition}", timeout=timeout)

    def wait_for_runlevel(self, level: int, timeout: int = 900) -> None:
        """
        Wait for finit to reach a specific runlevel.

        Args:
            level: The runlevel number (0-9, S)
            timeout: Maximum time to wait in seconds
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

    def wait_for_service(self, service: str, timeout: int = 900) -> None:
        """
        Wait for a finit service to be running.

        Args:
            service: The service name
            timeout: Maximum time to wait in seconds
        """
        self.wait_for_condition(f"service/{service}/running", timeout=timeout)

    def wait_for_task(self, task: str, timeout: int = 900) -> None:
        """
        Wait for a finit task to complete successfully.

        Args:
            task: The task name
            timeout: Maximum time to wait in seconds
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
        self, unit: str, user: str | None = None, timeout: int = 900
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
