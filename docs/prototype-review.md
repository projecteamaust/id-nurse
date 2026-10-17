# Prototype review (design/prototype/)

Source: `design/prototype/src/App.tsx` (all screens, hard-coded data) and `src/index.css` (colors, fonts, spacing).
The prototype has two apps: the **Nurse kiosk** (17 screen states, opens first) and the **Admin console**
(9 pages, opened from "Admin sign in" in the top bar).

> **Decisions on the conflicts in section 4 are in CLAUDE.md → Decisions. Where they differ, the decisions win.**
> The exact API shapes are in `docs/api.md`.

General notes:
- `design/` contains no PNG exports, only this prototype.
- The prototype is English and left-to-right. Decision: we keep English only, LTR, IBM Plex Sans.
- `body { min-width: 1100px }` and fixed 3-column grids: the Flutter version needs its own responsive layout for tablets.

---

## 1. Shared design (index.css)

**Font:** IBM Plex Sans, weights 400/500/600/700, base size 18px.

| Element | Style |
|---|---|
| h1 | 32px, weight 600, letter-spacing −0.02em (27px in the admin header) |
| h2 / h3 | 22px / 19px |
| Eyebrow label | 13px, weight 700, UPPERCASE, letter-spacing 0.08em, teal |
| Chip | 12px, weight 700, fully rounded, min height 28 |
| Table header | 13px, UPPERCASE, muted color, background `#f7faf9` |
| Stat number | 31px |

**Colors (CSS variables):**

| Token | Hex | Token | Hex |
|---|---|---|---|
| primary | `#0f766e` | success | `#15803d` (bg `#e7f7ed`) |
| primary-dark | `#0b5a54` | warning | `#b45309` (bg `#fef3c7`) |
| primary-light | `#ddf1ee` | error | `#b91c1c` (bg `#feeaea` / `#fff1f1`) |
| bg | `#f3f7f6` | text | `#12302d` |
| card | `#ffffff` | muted | `#5b7370` |
| border | `#d5e2df` | admin sidebar | `#102e2b` (text `#b9cdca`) |

**Other hard-coded colors:**
- Neutral chip: `#edf2f1`
- Disabled step: `#8aa09d`
- Cabinet: `#edf3f2` and `#cadbd8`
- Open door: `#253c39`
- Toast background: `#12302d`
- Warning alert text: `#713f12` (border `#f8d675`)

**Sizes and spacing:**
- Buttons: min height 56, radius 14, padding 0 24px. Keypad buttons are 64px tall with 22px text. The large button is 68px tall and 300px wide.
- Cards: radius 20, padding 32 (main card) or 22 (admin card), border `#d5e2df`.
- Main card max width: 1184px, or 720px for narrow cards.
- Top bar: 80px tall. Step tracker: 48px tall with 7 steps.

**Button variants:**
- primary: filled teal
- secondary: white with a border
- danger: red text on `#fff1f1`
- ghost: teal text, no background

**Shared widgets:**
- Top bar: logo (teal square with a white cross) and "ID Nurse"
- Step tracker: Identify, Patient, Supplies, Review, Prepare, Collect, Complete
- Number keypad: 1–9, Clear, 0, Back
- Patient card, modal, toast, alert (warning / error / success), data table, cabinet diagram

---

## 2. Nurse kiosk screens

Every screen after sign-in shows the same header: nurse name, ward ("Ward 4 · Surgical"), and a **Sign out** button.

| # | Screen | Text | User actions | API needed |
|---|---|---|---|---|
| 1 | **Identify** | "Identify yourself" / "Scan your nurse card or enter your ID." Tabs: Scan card \| Enter ID. "Hold your card against the reader below the screen". Errors: "The card could not be read…" and "No staff ID found…" | Switch tabs, simulate a scan, type a 4–6 digit ID on the keypad, "Find my ID", "Admin sign in" | `POST /auth/login` |
| 2 | **Confirm nurse** | "Is this you?" / "Confirm your details before continuing." Shows avatar, name, Staff ID, ward | "Yes, continue" / "No, go back" | `GET /me` |
| 3 | **Home** | "WARD 4 · SURGICAL", "Hello, {first name}", "What do you need to do?" Three cards: New supply request, My recent requests, Report a problem. A "Recent requests" section with an empty state: "No requests yet" | Open any of the three cards, "View all" | `GET /orders` |
| 4 | **Patient** | "Which patient?" / "Enter the patient ID." Green note: "Patient details are used only for this supply request." Error: "No patient with this ID…" | Keypad entry (5–8 digits), "Find patient", "Back" | `GET /patients/{file_number}` |
| 5 | **Confirm patient** | "Is this the right patient?" Card shows name, ID, age, room, diagnosis | "Yes, select supplies" / "No, enter again" | Same patient call |
| 6 | **Supplies** (3 columns) | Left: "Supplies", search box, categories (Wound care, IV and injections, Gloves and protection, Catheters and tubes, Hygiene), "Suggestions — COMING SOON". Middle: "PATIENT {id}", category title, item cards with chips "Drawer C3", "In stock" / "Low · 9" / "Out of stock", and "{n} units available". Right: "Your request", empty state "Your request is empty", "Total units", "Review request". Warning: "This quantity is higher than usual. A supervisor must approve it." | Search, pick a category, change quantity with − / + (max 30), "Add", "Remove", "Notify admin" (out of stock), "Review request" | `GET /items` |
| 7 | **Review** | "Review your request" / "Confirm the patient and supplies before authorizing." Patient card, item lines with drawer, "Total {n} units", high-quantity warning | "Edit items", "Authorize request" | `POST /orders`, then `POST /orders/{id}/approve` |
| 8 | **Supervisor approval** (when any quantity is over 10) | "HIGH QUANTITY", "Supervisor approval needed" / "Ask a supervisor to scan their card or enter their ID." Then: "Supervisor identified, Elena Ruiz · Ward supervisor" | Keypad, "Identify supervisor", "Approve", "Cancel request" | Missing → *Decided: left out (future)* |
| 9 | **Robot / Preparing** | "PLEASE WAIT NEARBY", "Preparing your request" / "The cabinet is retrieving and packing your supplies." Chip "About {n} sec". Stages: Request received → Robot retrieving items → Packing in one container → Ready for collection. Cabinet diagram (drawers A1–C4), "Item x of y", "Now working… Moving to drawer C3 · Sterile gauze pads" | "Cancel request" opens a dialog: "Cancel this request? Items already picked will be returned to their drawers." with "Keep request" / "Cancel request". Also simulate missing item and simulate fault (prototype only) | Poll `GET /orders/{id}` |
| 10 | **System error** | Red chip "Robot fault", "Robot stopped" / "…Your request is saved. Call maintenance or try again." | "Try again", "Call maintenance" (toast: "Maintenance has been called.") | Missing (retry, maintenance) |
| 11 | **Item missing** | Chip "Stock issue", "Item missing from drawer" / "Sterile gauze pads could not be found in drawer C3…" | "Continue without this item", "Cancel request" | Missing → *Decided: left out* |
| 12 | **Collect** | "READY FOR COLLECTION", "Your items are ready", "Use the dispensing door below the screen." Door graphic "B2 CLOSED/OPEN". After 60s: "Door still open. Please collect your items." | "Open door", "I have collected the items", "Remind me", "Call for help" | Missing → *Decided: frontend-only step after DONE* |
| 13 | **Complete** | Green ✓, "REQUEST COMPLETE", "Your transaction is recorded". Receipt: Transaction ID, date and time, patient ID, nurse, items | "New request", "Back to home", "Sign out" | Data from `GET /orders/{id}` |
| 14 | **Recent requests** | "My recent requests" / "Requests made during your recent shifts." Table: Date and time, Patient ID, Items, Status | "View", "Back" | `GET /orders` |
| 15 | **Request detail** | "Request detail", transaction ID, receipt | "Back" | `GET /orders/{id}` |
| 16 | **Report a problem** | "Report a problem" / "…The maintenance team will be notified." Problem type list: Item missing, Door will not open, Robot stopped, Wrong item received, Other. Field: "What happened?" | "Send report" (toast), "Cancel" | *Added: `POST /orders/{id}/report`* (PARTIAL/FAILED only, optional note; no problem-type list) |
| 17 | **Timeout** | Chip "Session ended", "Session timed out" / "You were signed out after 2 minutes of no activity." | "Identify yourself" | None (frontend timer) |

## 3. Admin console pages

The admin console has a dark sidebar (`#102e2b`) with these items: Overview, Transactions, Inventory & drawers,
Robot & system, Alerts (badge "4"), Reports, Users, Settings. At the bottom is "Elena Ruiz, Administrator" with a
Sign out button. The page header shows "ID NURSE ADMIN", the page title, and "All systems operational · Updated just now".

*Decided: only stock, low stock, dispensing log and report export are built now. The other pages may come later.*

| Page | Content | Actions | API needed |
|---|---|---|---|
| **Admin sign in** | Same layout as nurse Identify: "Admin sign in" / "Scan your staff card or enter your ID." | Scan or enter ID, "Back" | `POST /auth/login` with password (decided) |
| **Overview** | 4 stat cards: Requests today 124, Items dispensed 438, Low-stock items 8, Open alerts 4. "Requests per hour" line chart (today vs yesterday, "Live"). "Robot status" panel: current request, queue, drawer. "Recent alerts" list | Click any card to jump to its page, "View system status", "View all alerts" | Missing (stats, robot status); low stock via `/reports` |
| **Transactions** | Search ("Search transaction, patient or nurse"), Date range filter, Status filter. Table: Date and time, Transaction ID, Patient ID, Nurse, Items, Units, Status | Search, filter, "Export CSV", click a row to open it | `GET /orders`, `/reports` dispense CSV |
| **Transaction detail** | "Transaction information": ID, patient, nurse and staff ID, Supervisor approval, Requested, Collected. "Items dispensed" table with Result. "Status timeline": authorized, robot started, retrieved, door opened, collected | "Back to transactions" | `GET /orders/{id}` + `/audit` |
| **Inventory & drawers** | Switch between "Drawer map" and "Table view". Drawer cards show slot, status chip (Empty / Low / In stock), name, units. Refill dialog: "Refill drawer C3", "Quantity to add" | "Add item", "Refill drawer", "Edit item", Save / Cancel | `/items` (supervisor edit) |
| **Robot & system** | "Robot position, Live cabinet view", Working/Paused chip. System status: queue, door, drawer sensors, last maintenance. "Waiting requests" list. "Recent faults" table | "Pause robot" / "Resume robot", "Run test cycle" | Partly `/calibrate` (test pick); the rest is missing |
| **Alerts** | Tabs: Low stock, Unusual consumption, Faults, Reports from nurses. Expected vs actual bar chart. Alert cards | Switch tabs, "View details", "Mark as resolved" | Low stock via `/reports`; the rest is missing |
| **Reports** | Form: Report type (Insurance claim / Audit log / Consumption by ward), Date range, Patient ID (optional). Preview: "Insurance claim report", totals, Claim value $24,680, table | "Generate report", "Download PDF", "Back" | `/reports`, `/audit` (PDF and Excel are a later phase) |
| **Users** | Table: Name, Staff ID, Ward, Role, Status. "Add user" dialog: name, staff ID, ward, role | "Add user", "Activate" / "Deactivate" | Missing |
| **Settings** | Session timeout (2/5/10 min), Robot speed (Standard/Reduced/Fast), Language (English/العربية) | "Reset", "Save changes" | Missing |

---

## 4. Things the plan or API didn't cover

**Direct conflicts with CLAUDE.md or the docs**
1. **Login method.** The prototype signs in with a card scan or an ID only, with no password; the old plan used ID + password.
   → *Decided: nurses sign in with ID only (scan or manual); supervisors keep a password. Known limitation.*
2. **Cancelling during dispensing.** The prototype allows it; the API allows `CANCELLED` only before approval.
   → *Decided: cancel only before approval; no cancel on the dispensing screen.*
3. **"Continue without this item."** The prototype asks the nurse; the backend retries once, then stops.
   → *Decided: left out; the screen shows the PARTIAL/FAILED result.*
4. **Supervisor co-approval above 10 units.** No API support.
   → *Decided: left out for now (future feature).*
5. **Admin console size.** The plan has one supervisor dashboard; the prototype has 9 pages and says "Administrator".
   → *Decided: build only stock, low stock, dispensing log, report export.*
6. **Order states don't match.** The prototype has 4 stages, then Collect, then Complete, and no PARTIAL screen.
   → *Decided: keep `PENDING → DISPENSING → DONE | PARTIAL | FAILED`; add a PARTIAL screen; Collect and Complete are frontend steps after DONE.*

**Missing endpoints**
- List orders → *added: `GET /orders`.*
- Report a problem → *added: `POST /orders/{id}/report`, `GET /problem-reports`, `POST /problem-reports/{id}/resolve`
  (stored in `audit_log`). The supervisor dashboard shows open reports with "Mark resolved": an addition to Decision 5,
  asked for by the team.*
- Call maintenance / notify admin about out-of-stock items (later).
- Door open/close and "I have collected" (no door hardware; frontend-only step).
- Retrying a failed order (later).
- Dashboard numbers, hourly chart, robot queue and position, pause/resume (later).
- Alerts: unusual consumption, faults, mark as resolved (later).
- User management, system settings (later).

**Missing data fields**
- Patients: age, room → *added: `date_of_birth` (API returns `age`) and `room`.* The prototype says "patient ID"; ours is `file_number`.
- Items: `category` → *added.* Drawers like "C3" map to our numeric `slot_number`. "Low stock" uses `min_quantity` per item, not a fixed 10.
- Users: `ward` → *added.* Active/inactive flag (later).
- Prices for "Claim value $" (not planned).
- Order timeline timestamps beyond created/approved/completed come from `audit_log`.

**Frontend-only items**
- 2-minute inactivity timeout (the JWT itself lasts 8 hours).
- "Is this you?" confirmation.
- Remaining-time estimate and per-item progress (calculated from `qty_dispensed` in `GET /orders/{id}`).

**In the plan but missing from the prototype**
- Scanning a patient file number (Patient screen only has keypad entry).
- The supervisor calibration page (planned separately as `static/calibrate.html`).

**Prototype-only, leave out:** "Simulate card scan / unread card / missing item / robot fault" buttons and
"Suggestions — Coming soon" (`diagnosis_code` is reserved for future AI).
