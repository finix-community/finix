"""Bounded, synchronous QMP transport for the Finix test driver"""

import datetime as dt
import json
import socket
import threading
import time
from collections import deque
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any, Self, cast

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
    def __init__(self, sock: socket.socket) -> None:
        self.sock = sock
        self._buffer = b""
        self._next_id = 0
        self._lock = threading.RLock()
        self._events: deque[dict[str, Any]] = deque()
        self._closed = False
        try:
            hello = self._receive(time.monotonic() + 30)
            if "QMP" not in hello:
                raise RuntimeError(f"Invalid QMP greeting: {hello}")
            self.send("qmp_capabilities")
        except BaseException:
            self.close()
            raise

    @classmethod
    def from_path(cls, path: Path) -> Self:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.settimeout(30)
            sock.connect(str(path))
            return cls(sock)
        except BaseException:
            sock.close()
            raise

    def close(self) -> None:
        if not self._closed:
            self._closed = True
            self.sock.close()

    def discard_events(self, event_filter: EventFilter) -> None:
        with self._lock:
            self._events = deque(
                event for event in self._events if not event_filter(event)
            )

    def _receive(self, deadline: float) -> dict[str, Any]:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Timed out waiting for QMP")
            if b"\n" in self._buffer:
                break
            self.sock.settimeout(remaining)
            try:
                chunk = self.sock.recv(65536)
            except TimeoutError as error:
                self.close()
                raise TimeoutError("Timed out waiting for QMP") from error
            except BaseException:
                self.close()
                raise
            if not chunk:
                self.close()
                raise EOFError("QMP connection closed")
            self._buffer += chunk
        line, self._buffer = self._buffer.split(b"\n", 1)
        try:
            message = json.loads(line)
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            self.close()
            raise RuntimeError("Invalid JSON received from QMP") from error
        if not isinstance(message, dict):
            self.close()
            raise RuntimeError(f"Invalid QMP message (expected object): {message!r}")
        return cast("dict[str, Any]", message)

    def send(
        self,
        cmd: str,
        args: dict[str, Any] | None = None,
        timeout: dt.timedelta = dt.timedelta(seconds=30),
    ) -> dict[str, Any]:
        with self._lock:
            if self._closed:
                raise RuntimeError("QMP connection is closed")
            self._next_id += 1
            transaction = self._next_id
            request = {"execute": cmd, "arguments": args or {}, "id": transaction}
            deadline = time.monotonic() + timeout.total_seconds()
            try:
                self.sock.settimeout(max(0.001, timeout.total_seconds()))
                self.sock.sendall(json.dumps(request).encode() + b"\n")
                while True:
                    message = self._receive(deadline)
                    if "event" in message:
                        self._events.append(message)
                        continue
                    if message.get("id") != transaction:
                        raise RuntimeError(f"Unexpected QMP response: {message}")
                    if "error" in message:
                        raise QMPAPIError(message)
                    if "return" not in message:
                        raise RuntimeError(f"Invalid QMP response: {message}")
                    return message
            except QMPAPIError:
                raise
            except BaseException:
                self.close()
                raise

    def wait_for_event(
        self,
        timeout: dt.timedelta = dt.timedelta(seconds=10),
        event_filter: EventFilter | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            deadline = time.monotonic() + timeout.total_seconds()
            while True:
                for event in list(self._events):
                    if event_filter is None or event_filter(event):
                        self._events.remove(event)
                        return event

                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("Timed out waiting for QMP event")
                message = self._receive(deadline)
                if "event" not in message:
                    self.close()
                    raise RuntimeError(f"Expected QMP event: {message}")
                self._events.append(message)

    def events(
        self, timeout: dt.timedelta = dt.timedelta(seconds=10)
    ) -> Iterator[dict[str, Any]]:
        with self._lock:
            while self._events:
                yield self._events.popleft()
