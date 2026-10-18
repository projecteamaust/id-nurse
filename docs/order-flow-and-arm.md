# Order flow and arm control

## Order flow
1. Nurse logs in and receives a JWT.
2. She enters the patient file number, chooses items and quantities, and the UI calls `POST /orders`.
3. Server validates patient, stock, and order limits, then creates the order as `PENDING`.
4. Nurse reviews and approves: `POST /orders/{id}/approve`. State becomes `DISPENSING`, and a command is added to the
   arm's queue (`dispense_commands`, status `pending`) with the pickup path.
5. The arm worker (a background thread in the server) takes the oldest pending command (status `in_progress`).
   It gets the units to pick, **sorted by cabinet location** (top row first, left to right), and the path:
   `home -> each drawer -> pickup window -> home`.
6. For each unit the worker asks the arm to pick it and reports the result right after:
   on success: decrease stock, increase `qty_dispensed`, write `pick_ok` to `audit_log` (one transaction).
   On failure (drawer empty or arm fault): write `pick_failed`, retry once, then stop picking.
7. The arm brings the box to the pickup window and the worker reports the delivery. Final state:
   `DONE` (all picked), `PARTIAL` (some picked), or `FAILED` (nothing picked, or the box could not be delivered).
   The command becomes `completed` (a box was delivered) or `failed`. `order_finished` is written to `audit_log`.
8. UI polls until final. Nurse collects the box; supervisor pulls reports when needed.

If the server stops while dispensing, the command goes back to `pending` on the next start, and only the units that
are still missing are picked.

## Code (`backend/app/`)
- `services.py`: the queue functions (`claim_next_command`, `record_pick_ok`, `record_pick_failed`, `finish_command`).
- `worker.py`: `ArmWorker`, the loop that drives the arm and calls those functions. One worker, one arm:
  run the server with a single process.
- `arm.py`: `ArmDriver` interface with `home()`, `pick(slot)`, `deliver()`, and two drivers, so we can swap the
  simulator for the real arm with one config change:
  - `SimulatedArm`: simulates moves (a delay per move) and success/failure (supports forced failures for tests)
  - `SerialArm`: talks to the Arduino over Serial (pyserial). Not tested on real hardware yet.

Mode is chosen from config (`ARM_MODE=mock|real`, `SERIAL_PORT=COMx`, `ARM_SIM_STEP_SECONDS` for the simulator).

## Serial protocol (USB, 115200 baud, text lines)
| Command | Meaning | Reply |
|---|---|---|
| `PING` | connection check | `PONG` |
| `M a1,a2,a3,a4,a5,a6` | move the 6 joints gradually to these angles | `OK` or `ERR` (invalid command) |

The last angle is the gripper.

## Pick sequence per slot (Repeat and Teach)
Angles for each slot are saved once during calibration (table `poses`), then replayed:
`home` -> `approach_slotN` -> `grab_slotN` (close gripper) -> `approach_slotN` -> `box` (open gripper), for each unit,
then `window` (the box at the pickup window) -> `home`.

## Safety (firmware, later phase)
- Min/max angle limits per joint
- Gradual motion: one step every 15 ms, never jump
- Start from the `home` pose
- External 5 to 6 V, 5 A supply with common GND to the Arduino; never power servos from the Arduino 5V pin
