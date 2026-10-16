# Order flow and arm control

## Order flow
1. Nurse logs in and receives a JWT.
2. She enters the patient file number, chooses items and quantities, and the UI calls `POST /orders`.
3. Server validates patient, stock, and order limits, then creates the order as `PENDING`.
4. Nurse reviews and approves: `POST /orders/{id}/approve`. State becomes `DISPENSING`.
5. Server dispenses in the background. For each item it sends movement commands to the arm and waits for `OK` after each move.
6. On a successful pick: decrease stock, update `qty_dispensed`, write to `audit_log`.
   On failure: retry once, then stop the order.
7. Final state: `DONE` (all picked), `PARTIAL` (some picked), or `FAILED`.
8. UI polls until final. Nurse collects the box; supervisor pulls reports when needed.

## ArmController interface (`app/arm.py`)
One interface, two implementations, so we can swap mock for real with one config change:
- `MockArm`: simulates moves and success/failure (supports forced failures for tests)
- `RealArm`: talks to Arduino over Serial (pyserial). Not tested on real hardware yet.

Mode is chosen from config (`ARM_MODE=mock|real`, `SERIAL_PORT=COMx`).

## Serial protocol (USB, 115200 baud, text lines)
| Command | Meaning | Reply |
|---|---|---|
| `PING` | connection check | `PONG` |
| `M a1,a2,a3,a4,a5,a6` | move the 6 joints gradually to these angles | `OK` or `ERR` (invalid command) |

The last angle is the gripper.

## Pick sequence per slot (Repeat and Teach)
Angles for each slot are saved once during calibration (table `poses`), then replayed:
`home` -> `approach_slotN` -> `grab_slotN` (close gripper) -> `approach_slotN` -> `box` (open gripper) -> `home`

## Safety (firmware, later phase)
- Min/max angle limits per joint
- Gradual motion: one step every 15 ms, never jump
- Start from the `home` pose
- External 5 to 6 V, 5 A supply with common GND to the Arduino; never power servos from the Arduino 5V pin
