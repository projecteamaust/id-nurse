"""The arm worker: takes approved orders from the queue and dispenses them, one at a time.

For each command it:
1. takes the next pending command (status -> in_progress), with the units sorted by cabinet location,
2. moves home, then picks each unit; after every pick it reports the result (stock and audit log),
3. a failed pick (empty drawer or arm fault) is tried once more; if it fails again, picking stops,
4. brings the box to the pickup window and reports the delivery (order -> DONE, PARTIAL or FAILED).

It runs on one background thread inside the server. Run the server with one process only:
there is one arm, so there must be one worker.
"""

import logging
import threading

from . import db, services
from .arm import ArmDriver, ArmError, SerialArm, SimulatedArm
from .config import settings

log = logging.getLogger("id_nurse.worker")


class ArmWorker:
    def __init__(self, driver: ArmDriver, poll_seconds: float = 0.5):
        self.driver = driver
        self.poll_seconds = poll_seconds
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        with db.session_scope() as session:
            count = services.recover_interrupted_commands(session)
        if count:
            log.warning("Restarting %d interrupted dispense command(s)", count)
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, name="arm-worker", daemon=True)
        self._thread.start()

    def stop(self, timeout: float = 10) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout)
        self.driver.close()

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                worked = self.run_once()
            except Exception:  # keep the worker alive; the error is in the server log
                log.exception("Arm worker error")
                worked = False
            if not worked:
                self._stop.wait(self.poll_seconds)

    def run_once(self) -> bool:
        """Dispense the next order in the queue. Returns False when the queue is empty."""
        with db.session_scope() as session:
            job = services.claim_next_command(session)
        if job is None:
            return False
        error = None
        try:
            delivered = self._dispense(job)
        except ArmError as e:
            delivered, error = False, f"arm error: {e}"
        except Exception as e:  # never leave an order stuck in DISPENSING
            log.exception("Dispensing order %d failed", job.order_id)
            delivered, error = False, f"unexpected error: {e}"
        with db.session_scope() as session:
            status = services.finish_command(session, job.command_id, delivered, error)
        log.info("Order %d finished: %s", job.order_id, status)
        return True

    def _dispense(self, job: services.DispenseJob) -> bool:
        """Picks every unit, then delivers. Returns True if a box was delivered."""
        self.driver.home()
        picked = job.already_dispensed
        for step in job.picks:
            if not self._pick_with_retry(job.order_id, step):
                break  # failed twice: stop the order, deliver what is in the box
            picked += 1
        if picked == 0:
            self.driver.home()
            return False  # nothing in the box: nothing to deliver
        self.driver.deliver()
        self.driver.home()
        return True

    def _pick_with_retry(self, order_id: int, step: services.PickStep) -> bool:
        for attempt in (1, 2):
            reason = self._try_pick(order_id, step)
            if reason is None:
                return True
            with db.session_scope() as session:
                services.record_pick_failed(session, order_id, step, reason, will_retry=attempt == 1)
        return False

    def _try_pick(self, order_id: int, step: services.PickStep) -> str | None:
        """One pick. Returns None on success, or the reason it failed."""
        with db.session_scope() as session:
            if not services.drawer_has_stock(session, step.item_id):
                return "drawer empty"
        try:
            self.driver.pick(step.slot_number)
        except ArmError as e:
            return f"arm fault ({e})"
        with db.session_scope() as session:
            services.record_pick_ok(session, order_id, step)
        return None


def _load_poses() -> dict[str, list[int]]:
    with db.session_scope() as session:
        return services.load_poses(session)


def create_driver() -> ArmDriver:
    """The arm chosen by ARM_MODE: mock = simulator, real = Arduino on SERIAL_PORT."""
    if settings.arm_mode == "real":
        return SerialArm(settings.serial_port, _load_poses)
    return SimulatedArm(settings.arm_sim_step_seconds)


def create_worker() -> ArmWorker:
    return ArmWorker(create_driver())
