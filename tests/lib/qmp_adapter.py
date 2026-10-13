"""Synchronous test-driver adapter for qemu-qmp's legacy API"""

import datetime as dt
import time
from collections import deque
from collections.abc import Callable
from contextlib import suppress
from pathlib import Path
from typing import Any, cast

from qemu.qmp import ExecuteError
from qemu.qmp.legacy import QEMUMonitorProtocol

EventFilter = Callable[[dict[str, Any]], bool]


class QMPAPIError(RuntimeError):
    class_name: str
    description: str
    transaction_id: Any

    def __init__(self, message: dict[str, Any]):
        raw_error = message.get("error")
        if not isinstance(raw_error, dict):
            raise RuntimeError(f"Malformed QMP API error response: {message}")
        error = cast("dict[str, Any]", raw_error)
        class_name = error.get("class", "unknown")
        self.class_name = (
            class_name if isinstance(class_name, str) else repr(class_name)
        )
        description = error.get("desc")
        self.description = description if isinstance(description, str) else repr(error)
        self.transaction_id = message.get("id")
        super().__init__(
            f"QMP {self.class_name} (id={self.transaction_id}): {self.description}"
        )


class QMPSession:
    def __init__(self, qmp: QEMUMonitorProtocol) -> None:
        self._qmp = qmp
        self._events: deque[dict[str, Any]] = deque()
        self._closed = False

    @classmethod
    def from_path(cls, path: Path) -> "QMPSession":
        qmp = QEMUMonitorProtocol(str(path))
        try:
            qmp.connect()
        except BaseException:
            qmp.close()
            raise
        return cls(qmp)

    def close(self) -> None:
        if not self._closed:
            self._closed = True
            with suppress(BaseException):
                self._qmp.close()

    def _drain_events(self) -> None:
        while True:
            event = self._qmp.pull_event(wait=False)
            if event is None:
                return
            self._events.append(dict(event))

    def discard_events(self, event_filter: EventFilter) -> None:
        self._drain_events()
        self._events = deque(event for event in self._events if not event_filter(event))

    def send(
        self,
        cmd: str,
        args: dict[str, Any] | None = None,
        timeout: dt.timedelta = dt.timedelta(seconds=30),
    ) -> dict[str, Any]:
        if self._closed:
            raise RuntimeError("QMP connection is closed")

        try:
            self._drain_events()
            self._qmp.settimeout(max(0.001, timeout.total_seconds()))
            response = self._qmp.cmd_raw(cmd, args or {})
            self._drain_events()
        except ExecuteError as error:
            received = getattr(error, "received", None)
            if not isinstance(received, dict):
                raise RuntimeError(
                    f"Malformed QMP API error response: {error}"
                ) from error
            raise QMPAPIError(dict(received)) from error
        except BaseException:
            self.close()
            raise
        return dict(response)

    def wait_for_event(
        self,
        timeout: dt.timedelta = dt.timedelta(seconds=10),
        event_filter: EventFilter | None = None,
    ) -> dict[str, Any]:
        deadline = time.monotonic() + max(0.0, timeout.total_seconds())
        while True:
            self._drain_events()
            for index, event in enumerate(self._events):
                if event_filter is None or event_filter(event):
                    del self._events[index]
                    return event

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Timed out waiting for QMP event")
            try:
                event = self._qmp.pull_event(wait=remaining)
            except TimeoutError as error:
                self.close()
                raise TimeoutError("Timed out waiting for QMP event") from error
            except BaseException:
                self.close()
                raise
            if event is not None:
                self._events.append(dict(event))
