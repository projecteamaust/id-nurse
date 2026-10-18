"""The arm drivers on their own (no database)."""

import tests  # noqa: F401  (test settings; must be the first import)
import unittest

from app.arm import ArmError, SerialArm, SimulatedArm


class FakeSerialPort:
    """Stands in for the Arduino: records what is sent and answers from a list."""

    def __init__(self, replies: list[str]):
        self.replies = list(replies)
        self.sent: list[str] = []
        self.closed = False

    def write(self, data: bytes) -> None:
        self.sent.append(data.decode("ascii"))

    def readline(self) -> bytes:
        return (self.replies.pop(0) + "\n").encode("ascii") if self.replies else b""

    def close(self) -> None:
        self.closed = True


POSES = {
    "home": [90, 90, 90, 90, 90, 10],
    "box": [0, 60, 60, 90, 90, 10],
    "window": [180, 60, 60, 90, 90, 10],
    "approach_slot1": [30, 80, 70, 90, 90, 10],
    "grab_slot1": [30, 70, 80, 90, 90, 70],
}


class SimulatedArmTest(unittest.TestCase):
    def test_moves(self):
        slept = []
        arm = SimulatedArm(step_seconds=0.5, sleep=slept.append)
        arm.home()
        arm.pick(3)
        arm.deliver()
        self.assertEqual(arm.moves, ["home", "approach_slot3", "grab_slot3", "approach_slot3", "box", "window"])
        self.assertEqual(slept, [0.5] * 6)

    def test_forced_faults(self):
        arm = SimulatedArm(step_seconds=0)
        arm.fail_slots = {2}
        arm.pick(1)
        with self.assertRaises(ArmError):
            arm.pick(2)
        arm.fail_after_picks = 1
        with self.assertRaises(ArmError):
            arm.pick(1)


class SerialArmTest(unittest.TestCase):
    def test_protocol(self):
        port = FakeSerialPort(["PONG"] + ["OK"] * 6)
        arm = SerialArm("COM9", lambda: POSES, connection=port)
        arm.home()
        arm.pick(1)
        arm.deliver()
        arm.close()
        self.assertEqual(port.sent[0], "PING\n")
        self.assertEqual(port.sent[1], "M 90,90,90,90,90,10\n")
        self.assertEqual(port.sent[3], "M 30,70,80,90,90,70\n")  # grab: gripper closed
        self.assertEqual(len(port.sent), 7)
        self.assertTrue(port.closed)

    def test_no_pong(self):
        with self.assertRaises(ArmError):
            SerialArm("COM9", lambda: POSES, connection=FakeSerialPort([]))

    def test_err_reply_and_missing_pose(self):
        arm = SerialArm("COM9", lambda: POSES, connection=FakeSerialPort(["PONG", "ERR"]))
        with self.assertRaises(ArmError):
            arm.home()
        arm = SerialArm("COM9", lambda: POSES, connection=FakeSerialPort(["PONG"]))
        with self.assertRaises(ArmError):
            arm.pick(5)  # slot 5 is not calibrated


if __name__ == "__main__":
    unittest.main()
