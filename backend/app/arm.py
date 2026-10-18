"""Robot arm drivers. One interface, two drivers, chosen by ARM_MODE in .env:

- SimulatedArm (ARM_MODE=mock): pretends to move, so the full cycle works without hardware.
- SerialArm (ARM_MODE=real): sends the Serial protocol from docs/order-flow-and-arm.md to the Arduino.
  Not tested on real hardware yet.

The worker (worker.py) only uses ArmDriver, so swapping the simulator for the real arm
needs no code change.
"""

import time
from abc import ABC, abstractmethod
from collections.abc import Callable


class ArmError(Exception):
    """The arm could not do a move (fault, no reply, pose not calibrated)."""


class ArmDriver(ABC):
    @abstractmethod
    def home(self) -> None:
        """Move to the safe start pose."""

    @abstractmethod
    def pick(self, slot_number: int) -> None:
        """Take one unit from this drawer and drop it in the box. Raises ArmError on failure."""

    @abstractmethod
    def deliver(self) -> None:
        """Bring the box to the pickup window. Raises ArmError on failure."""

    def close(self) -> None:
        """Release the connection, if any."""


def pick_moves(slot_number: int) -> list[str]:
    """Pose names for one pick (Repeat and Teach): approach, grab (gripper closes), back out, drop in the box."""
    return [f"approach_slot{slot_number}", f"grab_slot{slot_number}", f"approach_slot{slot_number}", "box"]


class SimulatedArm(ArmDriver):
    """A fake arm. It never touches hardware; every move just waits step_seconds.

    For tests and demos, faults can be forced:
    - fail_slots: picks from these drawers always fail
    - fail_after_picks: after this many good picks, every pick fails (0 = fail from the start)
    """

    def __init__(self, step_seconds: float = 0.25, sleep: Callable[[float], None] = time.sleep):
        self.step_seconds = step_seconds
        self._sleep = sleep
        self.fail_slots: set[int] = set()
        self.fail_after_picks: int | None = None
        self.good_picks = 0
        self.moves: list[str] = []  # every pose visited, so tests can check the path

    def _move(self, pose: str) -> None:
        self.moves.append(pose)
        if self.step_seconds > 0:
            self._sleep(self.step_seconds)

    def home(self) -> None:
        self._move("home")

    def pick(self, slot_number: int) -> None:
        self._move(f"approach_slot{slot_number}")
        fault = slot_number in self.fail_slots or (
            self.fail_after_picks is not None and self.good_picks >= self.fail_after_picks)
        if fault:
            raise ArmError(f"simulated fault at slot {slot_number}")
        for pose in pick_moves(slot_number)[1:]:
            self._move(pose)
        self.good_picks += 1

    def deliver(self) -> None:
        self._move("window")


class SerialArm(ArmDriver):
    """The real arm: an Arduino on USB Serial (115200 baud, one text command per line).

    PING -> PONG checks the connection. "M a1,a2,a3,a4,a5,a6" moves the 6 joints to these
    angles and the Arduino answers OK (or ERR). The angles of every pose come from the
    poses table (calibration). Not tested on real hardware yet.
    """

    def __init__(self, port: str, load_poses: Callable[[], dict[str, list[int]]],
                 baudrate: int = 115200, timeout_seconds: float = 15, connection=None):
        if connection is None:
            import serial  # pyserial, only needed for the real arm

            connection = serial.Serial(port, baudrate, timeout=timeout_seconds)
        self._serial = connection
        self._load_poses = load_poses
        self._send("PING", expect="PONG")

    def _send(self, line: str, expect: str = "OK") -> None:
        self._serial.write(f"{line}\n".encode("ascii"))
        reply = self._serial.readline().decode("ascii", errors="replace").strip()
        if reply != expect:
            raise ArmError(f"arm answered {reply or 'nothing'!r} to {line.split()[0]}")

    def _move(self, pose: str) -> None:
        angles = self._load_poses().get(pose)
        if angles is None or len(angles) != 6:
            raise ArmError(f"pose {pose!r} is not calibrated")
        self._send("M " + ",".join(str(int(a)) for a in angles))

    def home(self) -> None:
        self._move("home")

    def pick(self, slot_number: int) -> None:
        for pose in pick_moves(slot_number):
            self._move(pose)

    def deliver(self) -> None:
        self._move("window")

    def close(self) -> None:
        self._serial.close()
