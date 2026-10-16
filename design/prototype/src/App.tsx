import { useEffect, useMemo, useState } from "react";

type Screen =
  | "identify"
  | "confirm-nurse"
  | "home"
  | "patient"
  | "confirm-patient"
  | "supplies"
  | "review"
  | "approval"
  | "robot"
  | "collect"
  | "complete"
  | "recent"
  | "detail"
  | "problem"
  | "system-error"
  | "item-missing"
  | "timeout";
type AdminPage =
  | "overview"
  | "transactions"
  | "transaction-detail"
  | "inventory"
  | "robot"
  | "alerts"
  | "reports"
  | "users"
  | "settings";
type Supply = {
  id: number;
  name: string;
  category: string;
  drawer: string;
  stock: number;
};
type Cart = Record<number, number>;

const categories = [
  "Wound care",
  "IV and injections",
  "Gloves and protection",
  "Catheters and tubes",
  "Hygiene",
];

const supplies: Supply[] = [
  { id: 1, name: "Sterile gauze pads", category: "Wound care", drawer: "C3", stock: 42 },
  { id: 2, name: "Adhesive dressing", category: "Wound care", drawer: "C4", stock: 18 },
  { id: 3, name: "Wound cleansing wipes", category: "Wound care", drawer: "D1", stock: 0 },
  { id: 4, name: "Transparent film", category: "Wound care", drawer: "D2", stock: 9 },
  { id: 5, name: "IV administration set", category: "IV and injections", drawer: "A2", stock: 21 },
  { id: 6, name: "10 ml syringe", category: "IV and injections", drawer: "A3", stock: 34 },
  { id: 7, name: "Safety needle", category: "IV and injections", drawer: "A4", stock: 11 },
  { id: 8, name: "Nitrile gloves, M", category: "Gloves and protection", drawer: "B1", stock: 64 },
  { id: 9, name: "Procedure mask", category: "Gloves and protection", drawer: "B2", stock: 26 },
  { id: 10, name: "Urinary catheter", category: "Catheters and tubes", drawer: "E2", stock: 7 },
  { id: 11, name: "Suction tubing", category: "Catheters and tubes", drawer: "E3", stock: 13 },
  { id: 12, name: "Patient cleansing cloths", category: "Hygiene", drawer: "F1", stock: 31 },
];

const mockTransactions = [
  { id: "TX-260321-0847", time: "Today, 08:47", patient: "284913", nurse: "Maya Chen", items: "3 items", units: 7, status: "Complete" },
  { id: "TX-260321-0812", time: "Today, 08:12", patient: "548220", nurse: "Omar Ali", items: "2 items", units: 4, status: "Complete" },
  { id: "TX-260320-2249", time: "Yesterday, 22:49", patient: "391782", nurse: "Leah Morgan", items: "5 items", units: 12, status: "Approval" },
  { id: "TX-260320-2110", time: "Yesterday, 21:10", patient: "772194", nurse: "Maya Chen", items: "1 item", units: 2, status: "Complete" },
];

const nurseNames = ["Maya Chen", "Omar Ali", "Leah Morgan", "Jon Bell", "Nina Patel"];
const patientNames = ["Alex Morgan", "Sam Taylor", "Jordan Lee", "Casey Evans", "Robin Shah"];

function Button({
  children,
  variant = "primary",
  disabled,
  onClick,
  className = "",
  type = "button",
}: {
  children: React.ReactNode;
  variant?: "primary" | "secondary" | "danger" | "ghost";
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
  type?: "button" | "submit";
}) {
  return (
    <button type={type} className={`btn btn-${variant} ${className}`} disabled={disabled} onClick={onClick}>
      {children}
    </button>
  );
}

function TextField({
  label,
  value,
  onChange,
  placeholder,
  error,
  type = "text",
}: {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  error?: string;
  type?: string;
}) {
  return (
    <label className="field">
      {label && <span>{label}</span>}
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={Boolean(error)}
      />
      {error && <small className="field-error">{error}</small>}
    </label>
  );
}

function Logo() {
  return (
    <div className="brand">
      <span className="logo-mark" aria-hidden="true"><i /></span>
      <span>ID Nurse</span>
    </div>
  );
}

function StatusChip({ children, tone = "neutral" }: { children: React.ReactNode; tone?: string }) {
  return <span className={`chip chip-${tone}`}>{children}</span>;
}

function Header({
  person,
  ward,
  onSignOut,
  onAdmin,
}: {
  person?: string;
  ward?: string;
  onSignOut?: () => void;
  onAdmin?: () => void;
}) {
  return (
    <header className="topbar">
      <Logo />
      <div className="top-actions">
        {person ? (
          <>
            <div className="identity"><strong>{person}</strong><span>{ward}</span></div>
            <Button variant="secondary" onClick={onSignOut}>Sign out</Button>
          </>
        ) : (
          onAdmin && <Button variant="ghost" onClick={onAdmin}>Admin sign in</Button>
        )}
      </div>
    </header>
  );
}

function Keypad({ onDigit, onClear, onBack }: { onDigit: (d: string) => void; onClear: () => void; onBack: () => void }) {
  return (
    <div className="keypad" aria-label="Numeric keypad">
      {["1", "2", "3", "4", "5", "6", "7", "8", "9"].map((n) => <Button variant="secondary" key={n} onClick={() => onDigit(n)}>{n}</Button>)}
      <Button variant="secondary" onClick={onClear}>Clear</Button>
      <Button variant="secondary" onClick={() => onDigit("0")}>0</Button>
      <Button variant="secondary" onClick={onBack}>Back</Button>
    </div>
  );
}

function DigitEntry({
  value,
  setValue,
  min,
  max,
  onSubmit,
  button,
  error,
}: {
  value: string;
  setValue: (v: string) => void;
  min: number;
  max: number;
  onSubmit: () => void;
  button: string;
  error?: string;
}) {
  return (
    <div className="digit-entry">
      <TextField label="ID number" value={value} onChange={(v) => setValue(v.replace(/\D/g, "").slice(0, max))} placeholder="_ _ _ _ _ _" error={error} />
      <Keypad onDigit={(d) => setValue((value + d).slice(0, max))} onClear={() => setValue("")} onBack={() => setValue(value.slice(0, -1))} />
      <Button disabled={value.length < min} onClick={onSubmit}>{button}</Button>
    </div>
  );
}

function AuthPanel({
  heading,
  subtext,
  id,
  setId,
  onSuccess,
  onBack,
}: {
  heading: string;
  subtext: string;
  id: string;
  setId: (id: string) => void;
  onSuccess: () => void;
  onBack?: () => void;
}) {
  const [tab, setTab] = useState<"scan" | "id">("scan");
  const [reading, setReading] = useState(false);
  const [error, setError] = useState("");
  const scan = (fail = false) => {
    setError("");
    setReading(true);
    window.setTimeout(() => {
      setReading(false);
      if (fail) setError("The card could not be read. Scan again or enter your ID.");
      else onSuccess();
    }, 1000);
  };
  const find = () => {
    if (id.startsWith("0")) setError("No staff ID found. Check the number and try again.");
    else onSuccess();
  };
  return (
    <main className="auth-wrap">
      <section className="main-card auth-card">
        <div className="heading-group"><h1>{heading}</h1><p>{subtext}</p></div>
        <div className="tabs two">
          <button className={tab === "scan" ? "active" : ""} onClick={() => { setTab("scan"); setError(""); }}>Scan card</button>
          <button className={tab === "id" ? "active" : ""} onClick={() => { setTab("id"); setError(""); }}>Enter ID</button>
        </div>
        {error && <Alert tone="error">{error}</Alert>}
        {tab === "scan" ? (
          <div className="scan-panel">
            <div className="id-card-art"><div className={reading ? "scan-line active" : "scan-line"} /><span /><b /></div>
            <strong>{reading ? "Reading card…" : "Hold your card against the reader below the screen"}</strong>
            <Button disabled={reading} onClick={() => scan(false)}>{reading ? "Reading card…" : "Simulate card scan"}</Button>
            {error ? (
              <div className="button-row centered">
                <Button variant="secondary" onClick={() => scan(false)}>Scan again</Button>
                <Button variant="ghost" onClick={() => setTab("id")}>Enter ID</Button>
              </div>
            ) : (
              <button className="text-link" onClick={() => scan(true)}>Simulate unread card</button>
            )}
          </div>
        ) : (
          <DigitEntry value={id} setValue={setId} min={4} max={6} onSubmit={find} button="Find my ID" error={error || undefined} />
        )}
        {onBack && <Button variant="ghost" onClick={onBack}>Back</Button>}
      </section>
    </main>
  );
}

function Alert({ children, tone = "warning" }: { children: React.ReactNode; tone?: "warning" | "error" | "success" }) {
  return <div className={`alert alert-${tone}`} role="alert">{children}</div>;
}

function StepTracker({ current }: { current: number }) {
  const steps = ["Identify", "Patient", "Supplies", "Review", "Prepare", "Collect", "Complete"];
  return (
    <div className="step-tracker">
      {steps.map((step, index) => (
        <div className={index <= current ? "step active" : "step"} key={step}>
          <i /><span>{step}</span>
        </div>
      ))}
    </div>
  );
}

function PatientCard({ patientId }: { patientId: string }) {
  const index = Number(patientId.slice(-1) || 0) % patientNames.length;
  return (
    <div className="patient-card">
      <div className="avatar">{patientNames[index].split(" ").map((n) => n[0]).join("")}</div>
      <div><small>Patient</small><strong>{patientNames[index]}</strong><span>ID {patientId} · Age {34 + index * 7}</span></div>
      <div><small>Room</small><strong>{2 + index}B-{12 + index}</strong></div>
      <div><small>Diagnosis</small><strong>{["Post-operative care", "Cellulitis", "Dehydration", "Wound review", "Respiratory observation"][index]}</strong></div>
    </div>
  );
}

function NurseShell({
  children,
  nurse,
  step,
  signOut,
}: {
  children: React.ReactNode;
  nurse: { name: string; id: string };
  step: number;
  signOut: () => void;
}) {
  return (
    <>
      <Header person={nurse.name} ward="Ward 4 · Surgical" onSignOut={signOut} />
      <StepTracker current={step} />
      <main className="nurse-main">{children}</main>
    </>
  );
}

function CabinetDiagram({ active = 4, label }: { active?: number; label?: string }) {
  return (
    <div className="cabinet-wrap">
      <div className="cabinet">
        {Array.from({ length: 12 }).map((_, i) => <div key={i} className={i === active ? "drawer active" : "drawer"}>{String.fromCharCode(65 + Math.floor(i / 4))}{(i % 4) + 1}</div>)}
      </div>
      <div className={`robot robot-${active % 4}`}><i /></div>
      <div className="robot-path" />
      {label && <strong className="diagram-label">{label}</strong>}
    </div>
  );
}

function Modal({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal"><div className="modal-head"><h2>{title}</h2><button aria-label="Close" onClick={onClose}>×</button></div>{children}</div>
    </div>
  );
}

function NurseApp({ exitToAdmin }: { exitToAdmin: () => void }) {
  const [screen, setScreen] = useState<Screen>("identify");
  const [staffId, setStaffId] = useState("");
  const [patientId, setPatientId] = useState("");
  const [cart, setCart] = useState<Cart>({});
  const [toast, setToast] = useState("");
  const [selectedRequest, setSelectedRequest] = useState(mockTransactions[0]);
  const nurseIndex = Number(staffId.slice(-1) || 0) % nurseNames.length;
  const nurse = { name: nurseNames[nurseIndex], id: staffId };
  const signedIn = !["identify", "confirm-nurse", "timeout"].includes(screen);

  useEffect(() => {
    if (!signedIn) return;
    let timer = window.setTimeout(() => setScreen("timeout"), 120000);
    const reset = () => { window.clearTimeout(timer); timer = window.setTimeout(() => setScreen("timeout"), 120000); };
    window.addEventListener("pointerdown", reset);
    window.addEventListener("keydown", reset);
    return () => { window.clearTimeout(timer); window.removeEventListener("pointerdown", reset); window.removeEventListener("keydown", reset); };
  }, [signedIn, screen]);

  const signOut = () => { setScreen("identify"); setStaffId(""); setPatientId(""); setCart({}); };
  const content = (node: React.ReactNode, step: number) => <NurseShell nurse={nurse} step={step} signOut={signOut}><section className="main-card">{node}</section></NurseShell>;

  if (screen === "identify") {
    return <><Header onAdmin={exitToAdmin} /><AuthPanel heading="Identify yourself" subtext="Scan your nurse card or enter your ID." id={staffId} setId={setStaffId} onSuccess={() => { if (!staffId) setStaffId(String(Math.floor(10000 + Math.random() * 89999))); setScreen("confirm-nurse"); }} /></>;
  }
  if (screen === "confirm-nurse") {
    return <>
      <Header />
      <main className="nurse-main"><section className="main-card narrow">
        <div className="heading-group"><h1>Is this you?</h1><p>Confirm your details before continuing.</p></div>
        <div className="profile-card"><div className="avatar large">{nurse.name.split(" ").map((n) => n[0]).join("")}</div><div><h2>{nurse.name}</h2><p>Staff ID {nurse.id}</p><p>Ward 4 · Surgical</p></div></div>
        <div className="button-row"><Button onClick={() => setScreen("home")}>Yes, continue</Button><Button variant="secondary" onClick={() => setScreen("identify")}>No, go back</Button></div>
      </section></main>
    </>;
  }
  if (screen === "timeout") {
    return <><Header /><main className="auth-wrap"><section className="main-card narrow"><StatusChip tone="warning">Session ended</StatusChip><div className="heading-group"><h1>Session timed out</h1><p>You were signed out after 2 minutes of no activity.</p></div><Button onClick={signOut}>Identify yourself</Button></section></main></>;
  }
  if (screen === "home") {
    return content(<>
      <div className="heading-group"><p className="eyebrow">Ward 4 · Surgical</p><h1>Hello, {nurse.name.split(" ")[0]}</h1><p>What do you need to do?</p></div>
      <div className="home-actions">
        <button className="action-card primary-action" onClick={() => setScreen("patient")}><span>+</span><strong>New supply request</strong><small>Choose a patient and supplies</small></button>
        <button className="action-card" onClick={() => setScreen("recent")}><span>3</span><strong>My recent requests</strong><small>View completed requests</small></button>
        <button className="action-card" onClick={() => setScreen("problem")}><span>!</span><strong>Report a problem</strong><small>Tell maintenance about an issue</small></button>
      </div>
      <div className="section-head"><h2>Recent requests</h2><Button variant="ghost" onClick={() => setScreen("recent")}>View all</Button></div>
      <div className="empty-state"><div className="empty-icon">□</div><strong>No requests yet</strong><p>Start with a new supply request.</p></div>
      {toast && <div className="toast">{toast}</div>}
    </>, 0);
  }
  if (screen === "patient") {
    const patientError = patientId.startsWith("0") ? "No patient with this ID. Check the number and try again." : "";
    return content(<div className="two-col-entry">
      <div><div className="heading-group"><h1>Which patient?</h1><p>Enter the patient ID.</p></div><Alert tone="success">Patient details are used only for this supply request.</Alert></div>
      <DigitEntry value={patientId} setValue={setPatientId} min={5} max={8} error={patientError || undefined} button="Find patient" onSubmit={() => { if (!patientId.startsWith("0")) setScreen("confirm-patient"); }} />
      <Button variant="ghost" onClick={() => setScreen("home")}>Back</Button>
    </div>, 1);
  }
  if (screen === "confirm-patient") {
    return content(<>
      <div className="heading-group"><h1>Is this the right patient?</h1><p>Check the patient details before selecting supplies.</p></div>
      <PatientCard patientId={patientId} />
      <div className="button-row"><Button onClick={() => setScreen("supplies")}>Yes, select supplies</Button><Button variant="secondary" onClick={() => { setPatientId(""); setScreen("patient"); }}>No, enter again</Button></div>
    </>, 1);
  }
  if (screen === "supplies") return <SupplySelection nurse={nurse} patientId={patientId} cart={cart} setCart={setCart} onBack={() => setScreen("confirm-patient")} onReview={() => setScreen("review")} signOut={signOut} />;
  const highQuantity = Object.values(cart).some((q) => q > 10);
  if (screen === "review") {
    return content(<>
      <div className="heading-group"><h1>Review your request</h1><p>Confirm the patient and supplies before authorizing.</p></div>
      <PatientCard patientId={patientId} />
      {highQuantity && <Alert>This quantity is higher than usual. A supervisor must approve it.</Alert>}
      <div className="review-list">{Object.entries(cart).map(([id, q]) => { const item = supplies.find((s) => s.id === Number(id))!; return <div key={id}><div><strong>{item.name}</strong><span>Drawer {item.drawer}</span></div><b>{q} units</b></div>; })}</div>
      <div className="summary-total"><span>Total</span><strong>{Object.values(cart).reduce((a, b) => a + b, 0)} units</strong></div>
      <div className="button-row end"><Button variant="secondary" onClick={() => setScreen("supplies")}>Edit items</Button><Button onClick={() => setScreen(highQuantity ? "approval" : "robot")}>Authorize request</Button></div>
    </>, 3);
  }
  if (screen === "approval") return <SupervisorApproval nurse={nurse} signOut={signOut} onApprove={() => setScreen("robot")} onCancel={() => setScreen("supplies")} />;
  if (screen === "robot") return <RobotScreen nurse={nurse} signOut={signOut} onComplete={() => setScreen("collect")} onError={() => setScreen("system-error")} onMissing={() => setScreen("item-missing")} onCancel={() => setScreen("supplies")} itemCount={Object.values(cart).reduce((a, b) => a + b, 0)} />;
  if (screen === "system-error") {
    return content(<div className="error-state"><div className="fault-icon">!</div><StatusChip tone="error">Robot fault</StatusChip><h1>Robot stopped</h1><p>The robot stopped before finishing. Your request is saved. Call maintenance or try again.</p><div className="button-row centered"><Button onClick={() => setScreen("robot")}>Try again</Button><Button variant="secondary" onClick={() => setToast("Maintenance has been called.")}>Call maintenance</Button></div>{toast && <Alert tone="success">{toast}</Alert>}</div>, 4);
  }
  if (screen === "item-missing") {
    return content(<div className="error-state"><div className="fault-icon">!</div><StatusChip tone="warning">Stock issue</StatusChip><h1>Item missing from drawer</h1><p>Sterile gauze pads could not be found in drawer C3. Continue with the remaining items or cancel this request.</p><div className="button-row centered"><Button onClick={() => setScreen("robot")}>Continue without this item</Button><Button variant="danger" onClick={() => setScreen("supplies")}>Cancel request</Button></div></div>, 4);
  }
  if (screen === "collect") return <CollectScreen nurse={nurse} signOut={signOut} onDone={() => setScreen("complete")} />;
  if (screen === "complete") {
    const tx = `TX-${new Date().toISOString().slice(2, 10).replaceAll("-", "")}-${String(Date.now()).slice(-4)}`;
    return content(<>
      <div className="complete-head"><span>✓</span><div><p className="eyebrow success">Request complete</p><h1>Your transaction is recorded</h1></div></div>
      <Receipt transaction={tx} patientId={patientId} nurse={nurse.name} cart={cart} />
      <div className="button-row spread"><Button onClick={() => { setPatientId(""); setCart({}); setScreen("patient"); }}>New request</Button><Button variant="secondary" onClick={() => setScreen("home")}>Back to home</Button><Button variant="ghost" onClick={signOut}>Sign out</Button></div>
    </>, 6);
  }
  if (screen === "recent") {
    return content(<>
      <div className="section-head"><div className="heading-group"><h1>My recent requests</h1><p>Requests made during your recent shifts.</p></div><Button variant="secondary" onClick={() => setScreen("home")}>Back</Button></div>
      <DataTable headers={["Date and time", "Patient ID", "Items", "Status", ""]} rows={mockTransactions.slice(0, 3).map((t) => [t.time, t.patient, t.items, <StatusChip tone="success">{t.status}</StatusChip>, <Button variant="ghost" onClick={() => { setSelectedRequest(t); setScreen("detail"); }}>View</Button>])} />
    </>, 0);
  }
  if (screen === "detail") {
    return content(<><div className="section-head"><div className="heading-group"><h1>Request detail</h1><p>{selectedRequest.id}</p></div><Button variant="secondary" onClick={() => setScreen("recent")}>Back</Button></div><Receipt transaction={selectedRequest.id} patientId={selectedRequest.patient} nurse={nurse.name} cart={{ 1: 3, 2: 2, 8: 2 }} /></>, 0);
  }
  return content(<ProblemForm onCancel={() => setScreen("home")} onSend={() => { setScreen("home"); setToast("Report sent. The maintenance team has been notified."); window.setTimeout(() => setToast(""), 3500); }} />, 0);
}

function SupplySelection({ nurse, patientId, cart, setCart, onReview, signOut }: {
  nurse: { name: string; id: string }; patientId: string; cart: Cart; setCart: (c: Cart) => void; onBack: () => void; onReview: () => void; signOut: () => void;
}) {
  const [category, setCategory] = useState(categories[0]);
  const [search, setSearch] = useState("");
  const [draft, setDraft] = useState<Cart>({});
  const [suggestions, setSuggestions] = useState(false);
  const [notice, setNotice] = useState("");
  const filtered = supplies.filter((s) => s.category === category && s.name.toLowerCase().includes(search.toLowerCase()));
  const total = Object.values(cart).reduce((a, b) => a + b, 0);
  const setQty = (id: number, qty: number) => setDraft({ ...draft, [id]: Math.max(0, Math.min(30, qty)) });
  return (
    <><Header person={nurse.name} ward="Ward 4 · Surgical" onSignOut={signOut} /><StepTracker current={2} />
      <main className="supply-layout">
        <aside className="category-panel"><h2>Supplies</h2><label className="search"><span>Search</span><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search supplies" /></label><nav>{categories.map((c) => <button key={c} className={c === category ? "active" : ""} onClick={() => setCategory(c)}>{c}</button>)}</nav><button className="suggestion-toggle" onClick={() => setSuggestions(!suggestions)}><span>Suggestions</span><small>Coming soon</small></button>{suggestions && <p className="suggestion-note">Supply suggestions based on diagnosis will appear here in a future version.</p>}</aside>
        <section className="supply-center">
          <div className="section-head"><div><p className="eyebrow">Patient {patientId}</p><h1>{category}</h1></div><StatusChip>{filtered.length} supplies</StatusChip></div>
          {Object.values({ ...cart, ...draft }).some((q) => q > 10) && <Alert>This quantity is higher than usual. A supervisor must approve it.</Alert>}
          {notice && <Alert tone="success">{notice}</Alert>}
          <div className="supply-grid">{filtered.map((item) => {
            const qty = draft[item.id] || 0; const out = item.stock === 0;
            return <article key={item.id} className={out ? "supply-card disabled" : "supply-card"}>
              <div className="supply-meta"><StatusChip>Drawer {item.drawer}</StatusChip><StatusChip tone={out ? "error" : item.stock < 10 ? "warning" : "success"}>{out ? "Out of stock" : item.stock < 10 ? `Low · ${item.stock}` : "In stock"}</StatusChip></div>
              <h3>{item.name}</h3><p>{out ? "Unavailable for this request" : `${item.stock} units available`}</p>
              {out ? <Button variant="secondary" onClick={() => { setNotice("Admin notified about Wound cleansing wipes."); window.setTimeout(() => setNotice(""), 2500); }}>Notify admin</Button> :
                <><div className="stepper"><Button variant="secondary" onClick={() => setQty(item.id, qty - 1)} disabled={qty === 0}>−</Button><strong>{qty}</strong><Button variant="secondary" onClick={() => setQty(item.id, qty + 1)}>+</Button></div><Button disabled={qty === 0} onClick={() => { setCart({ ...cart, [item.id]: (cart[item.id] || 0) + qty }); setQty(item.id, 0); }}>Add</Button></>}
            </article>;
          })}</div>
        </section>
        <aside className="cart-panel"><div className="section-head"><h2>Your request</h2><StatusChip tone="teal">{total} units</StatusChip></div>{total === 0 ? <div className="cart-empty"><span>+</span><strong>Your request is empty</strong><p>Add supplies to continue.</p></div> : <div className="cart-lines">{Object.entries(cart).map(([id, q]) => { const item = supplies.find((s) => s.id === Number(id))!; return <div key={id}><div><strong>{item.name}</strong><small>Drawer {item.drawer}</small></div><div className="cart-line-actions"><b>{q}</b><button onClick={() => { const next = { ...cart }; delete next[Number(id)]; setCart(next); }}>Remove</button></div></div>; })}</div>}<div className="cart-footer"><div><span>Total units</span><strong>{total}</strong></div><Button disabled={total === 0} onClick={onReview}>Review request</Button></div></aside>
      </main>
    </>
  );
}

function SupervisorApproval({ nurse, signOut, onApprove, onCancel }: { nurse: { name: string; id: string }; signOut: () => void; onApprove: () => void; onCancel: () => void }) {
  const [id, setId] = useState("");
  const [identified, setIdentified] = useState(false);
  return <NurseShell nurse={nurse} step={3} signOut={signOut}><section className="main-card narrow">
    <div className="heading-group"><StatusChip tone="warning">High quantity</StatusChip><h1>Supervisor approval needed</h1><p>Ask a supervisor to scan their card or enter their ID.</p></div>
    {!identified ? <DigitEntry value={id} setValue={setId} min={4} max={6} button="Identify supervisor" onSubmit={() => setIdentified(true)} /> : <Alert tone="success"><strong>Supervisor identified</strong><br />Elena Ruiz · Ward supervisor</Alert>}
    <div className="button-row"><Button disabled={!identified} onClick={onApprove}>Approve</Button><Button variant="danger" onClick={onCancel}>Cancel request</Button></div>
  </section></NurseShell>;
}

function RobotScreen({ nurse, signOut, onComplete, onError, onMissing, onCancel, itemCount }: { nurse: { name: string; id: string }; signOut: () => void; onComplete: () => void; onError: () => void; onMissing: () => void; onCancel: () => void; itemCount: number }) {
  const [stage, setStage] = useState(0);
  const [confirm, setConfirm] = useState(false);
  const stages = ["Request received", "Robot retrieving items", "Packing in one container", "Ready for collection"];
  useEffect(() => {
    if (stage >= 3) { const done = window.setTimeout(onComplete, 1800); return () => window.clearTimeout(done); }
    const timer = window.setTimeout(() => setStage(stage + 1), 2000);
    return () => window.clearTimeout(timer);
  }, [stage, onComplete]);
  return <NurseShell nurse={nurse} step={4} signOut={signOut}><section className="main-card robot-screen">
    <div className="section-head"><div className="heading-group"><p className="eyebrow">Please wait nearby</p><h1>Preparing your request</h1><p>The cabinet is retrieving and packing your supplies.</p></div><StatusChip tone="teal">About {Math.max(1, 4 - stage) * 8} sec</StatusChip></div>
    <div className="working-steps">{stages.map((s, i) => <div className={i < stage ? "done" : i === stage ? "current" : ""} key={s}><i>{i < stage ? "✓" : i + 1}</i><span>{s}</span></div>)}</div>
    <div className="robot-content"><CabinetDiagram active={stage * 2 + 1} label={`Item ${Math.min(itemCount, stage * 2 + 1)} of ${itemCount}`} /><div className="current-action"><span className="pulse-dot" /><div><small>Now working</small><strong>{stages[stage]}</strong><p>{stage === 1 ? "Moving to drawer C3 · Sterile gauze pads" : "Your request is moving through the cabinet."}</p></div></div></div>
    <div className="button-row spread"><Button variant="danger" onClick={() => setConfirm(true)}>Cancel request</Button><div className="button-row"><Button variant="ghost" onClick={onMissing}>Simulate missing item</Button><Button variant="ghost" onClick={onError}>Simulate robot fault</Button></div></div>
    {confirm && <Modal title="Cancel this request?" onClose={() => setConfirm(false)}><p>Items already picked will be returned to their drawers.</p><div className="button-row end"><Button variant="secondary" onClick={() => setConfirm(false)}>Keep request</Button><Button variant="danger" onClick={onCancel}>Cancel request</Button></div></Modal>}
  </section></NurseShell>;
}

function CollectScreen({ nurse, signOut, onDone }: { nurse: { name: string; id: string }; signOut: () => void; onDone: () => void }) {
  const [open, setOpen] = useState(false);
  const [reminder, setReminder] = useState(false);
  useEffect(() => { if (!open) return; const timer = window.setTimeout(() => setReminder(true), 60000); return () => window.clearTimeout(timer); }, [open]);
  return <NurseShell nurse={nurse} step={5} signOut={signOut}><section className="main-card collect-screen">
    <div className="ready-icon">✓</div><div className="heading-group centered-text"><p className="eyebrow success">Ready for collection</p><h1>Your items are ready</h1><p>{open ? "Take your container, then close the door." : "Use the dispensing door below the screen."}</p></div>
    <div className={open ? "door open" : "door"}><span>Door</span><strong>B2</strong><i>{open ? "OPEN" : "CLOSED"}</i></div>
    {!open ? <Button className="large-button" onClick={() => setOpen(true)}>Open door</Button> : <Button className="large-button" onClick={onDone}>I have collected the items</Button>}
    {reminder && <Alert><strong>Door still open.</strong> Please collect your items.<div className="inline-actions"><Button variant="secondary" onClick={() => setReminder(false)}>Remind me</Button><Button variant="ghost">Call for help</Button></div></Alert>}
  </section></NurseShell>;
}

function Receipt({ transaction, patientId, nurse, cart }: { transaction: string; patientId: string; nurse: string; cart: Cart }) {
  return <div className="receipt"><div className="receipt-grid"><div><small>Transaction ID</small><strong>{transaction}</strong></div><div><small>Date and time</small><strong>{new Date().toLocaleString([], { dateStyle: "medium", timeStyle: "short" })}</strong></div><div><small>Patient ID</small><strong>{patientId}</strong></div><div><small>Nurse</small><strong>{nurse}</strong></div></div><h3>Items</h3>{Object.entries(cart).map(([id, q]) => <div className="receipt-line" key={id}><span>{supplies.find((s) => s.id === Number(id))?.name || "Medical supply"}</span><strong>{q} units</strong></div>)}</div>;
}

function ProblemForm({ onCancel, onSend }: { onCancel: () => void; onSend: () => void }) {
  const [type, setType] = useState("Item missing");
  const [note, setNote] = useState("");
  return <><div className="heading-group"><h1>Report a problem</h1><p>Tell us what happened. The maintenance team will be notified.</p></div><div className="form-stack"><label className="field"><span>Problem type</span><select value={type} onChange={(e) => setType(e.target.value)}>{["Item missing", "Door will not open", "Robot stopped", "Wrong item received", "Other"].map((v) => <option key={v}>{v}</option>)}</select></label><label className="field"><span>What happened?</span><textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Add any details that may help the maintenance team" /></label></div><div className="button-row"><Button onClick={onSend}>Send report</Button><Button variant="secondary" onClick={onCancel}>Cancel</Button></div></>;
}

function DataTable({ headers, rows, onRow }: { headers: string[]; rows: React.ReactNode[][]; onRow?: (index: number) => void }) {
  return <div className="table-wrap"><table><thead><tr>{headers.map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{rows.map((row, i) => <tr key={i} onClick={() => onRow?.(i)} className={onRow ? "clickable" : ""}>{row.map((cell, j) => <td key={j}>{cell}</td>)}</tr>)}</tbody></table></div>;
}

const navItems: { page: AdminPage; label: string; icon: string }[] = [
  { page: "overview", label: "Overview", icon: "⌂" },
  { page: "transactions", label: "Transactions", icon: "↔" },
  { page: "inventory", label: "Inventory & drawers", icon: "▦" },
  { page: "robot", label: "Robot & system", icon: "◎" },
  { page: "alerts", label: "Alerts", icon: "!" },
  { page: "reports", label: "Reports", icon: "▤" },
  { page: "users", label: "Users", icon: "◉" },
  { page: "settings", label: "Settings", icon: "⚙" },
];

function AdminApp({ exitToNurse }: { exitToNurse: () => void }) {
  const [signedIn, setSignedIn] = useState(false);
  const [staffId, setStaffId] = useState("");
  const [page, setPage] = useState<AdminPage>("overview");
  const [toast, setToast] = useState("");
  if (!signedIn) return <><Header /><AuthPanel heading="Admin sign in" subtext="Scan your staff card or enter your ID." id={staffId} setId={setStaffId} onSuccess={() => setSignedIn(true)} onBack={exitToNurse} /></>;
  const navigate = (p: AdminPage) => setPage(p);
  return <div className="admin-shell">
    <aside className="admin-sidebar"><Logo /><nav>{navItems.map((item) => <button key={item.page} className={page === item.page || (page === "transaction-detail" && item.page === "transactions") ? "active" : ""} onClick={() => navigate(item.page)}><i>{item.icon}</i>{item.label}{item.page === "alerts" && <b>4</b>}</button>)}</nav><div className="sidebar-foot"><div className="avatar">ER</div><div><strong>Elena Ruiz</strong><span>Administrator</span></div><button onClick={() => setSignedIn(false)}>Sign out</button></div></aside>
    <main className="admin-main"><header className="admin-header"><div><p className="eyebrow">ID Nurse admin</p><h1>{navItems.find((n) => n.page === page)?.label || "Transaction detail"}</h1></div><div className="system-ok"><span /><div><strong>All systems operational</strong><small>Updated just now</small></div></div></header>
      {page === "overview" && <Overview navigate={navigate} />}
      {page === "transactions" && <Transactions onOpen={() => setPage("transaction-detail")} />}
      {page === "transaction-detail" && <TransactionDetail onBack={() => setPage("transactions")} />}
      {page === "inventory" && <Inventory toast={(m) => { setToast(m); window.setTimeout(() => setToast(""), 3000); }} />}
      {page === "robot" && <RobotAdmin toast={(m) => { setToast(m); window.setTimeout(() => setToast(""), 3000); }} />}
      {page === "alerts" && <Alerts />}
      {page === "reports" && <Reports />}
      {page === "users" && <Users />}
      {page === "settings" && <Settings toast={(m) => { setToast(m); window.setTimeout(() => setToast(""), 3000); }} />}
      {toast && <div className="toast">{toast}</div>}
    </main>
  </div>;
}

function StatCard({ label, value, note, tone, onClick }: { label: string; value: string; note: string; tone?: string; onClick: () => void }) {
  return <button className="stat-card" onClick={onClick}><div className={`stat-icon ${tone || ""}`} /><span>{label}</span><strong>{value}</strong><small>{note}</small></button>;
}

function Overview({ navigate }: { navigate: (p: AdminPage) => void }) {
  return <div className="admin-content">
    <div className="stat-grid"><StatCard label="Requests today" value="124" note="12% more than yesterday" onClick={() => navigate("transactions")} /><StatCard label="Items dispensed" value="438" note="Across 6 wards" onClick={() => navigate("transactions")} /><StatCard label="Low-stock items" value="8" note="3 need urgent refill" tone="warning" onClick={() => navigate("inventory")} /><StatCard label="Open alerts" value="4" note="1 robot fault" tone="error" onClick={() => navigate("alerts")} /></div>
    <div className="dashboard-grid"><section className="admin-card chart-card"><div className="section-head"><div><h2>Requests per hour</h2><p>Today compared with yesterday</p></div><StatusChip tone="teal">Live</StatusChip></div><div className="line-chart"><div className="chart-y"><span>30</span><span>20</span><span>10</span><span>0</span></div><svg viewBox="0 0 700 210" preserveAspectRatio="none"><path className="grid-line" d="M0 20 H700 M0 80 H700 M0 140 H700 M0 200 H700" /><polyline className="line previous" points="0,165 70,145 140,152 210,110 280,125 350,82 420,94 490,55 560,72 630,40 700,52" /><polyline className="line current" points="0,180 70,154 140,138 210,125 280,92 350,108 420,70 490,78 560,42 630,56 700,24" /></svg><div className="chart-x">{["6am", "8am", "10am", "12pm", "2pm", "4pm"].map((x) => <span key={x}>{x}</span>)}</div></div></section>
      <section className="admin-card robot-status"><div className="section-head"><h2>Robot status</h2><StatusChip tone="success">Working</StatusChip></div><CabinetDiagram active={6} /><div className="robot-stats"><div><small>Current request</small><strong>TX-260321-0914</strong></div><div><small>Queue</small><strong>2 requests</strong></div><div><small>Current drawer</small><strong>B3</strong></div></div><Button variant="secondary" onClick={() => navigate("robot")}>View system status</Button></section></div>
    <section className="admin-card"><div className="section-head"><div><h2>Recent alerts</h2><p>Items that may need your attention</p></div><Button variant="ghost" onClick={() => navigate("alerts")}>View all alerts</Button></div><div className="alert-list">{[["Low stock", "Urinary catheter has 7 units remaining", "12 min ago", "warning"], ["Unusual consumption", "Nitrile gloves usage is 38% above expected", "34 min ago", "warning"], ["Nurse report", "Door B2 was slow to open", "1 hr ago", "neutral"]].map((a) => <button key={a[1]} onClick={() => navigate("alerts")}><span className={`alert-dot ${a[3]}`} /><div><strong>{a[0]}</strong><p>{a[1]}</p></div><time>{a[2]}</time><b>View</b></button>)}</div></section>
  </div>;
}

function Transactions({ onOpen }: { onOpen: () => void }) {
  const [search, setSearch] = useState("");
  const rows = mockTransactions.filter((t) => `${t.id}${t.patient}${t.nurse}`.toLowerCase().includes(search.toLowerCase()));
  const exportCsv = () => {
    const text = ["Transaction,Patient,Nurse,Units,Status", ...rows.map((r) => `${r.id},${r.patient},${r.nurse},${r.units},${r.status}`)].join("\n");
    const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([text], { type: "text/csv" })); a.download = "id-nurse-transactions.csv"; a.click();
  };
  return <div className="admin-content"><section className="admin-card"><div className="toolbar"><label className="search wide"><span>Search</span><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search transaction, patient or nurse" /></label><label className="compact-field"><span>Date range</span><select><option>Last 7 days</option><option>Today</option><option>Last 30 days</option></select></label><label className="compact-field"><span>Status</span><select><option>All statuses</option><option>Complete</option><option>Approval</option></select></label><Button variant="secondary" onClick={exportCsv}>Export CSV</Button></div><DataTable onRow={onOpen} headers={["Date and time", "Transaction ID", "Patient ID", "Nurse", "Items", "Units", "Status"]} rows={rows.map((t) => [t.time, <strong>{t.id}</strong>, t.patient, t.nurse, t.items, t.units, <StatusChip tone={t.status === "Complete" ? "success" : "warning"}>{t.status}</StatusChip>])} /></section></div>;
}

function TransactionDetail({ onBack }: { onBack: () => void }) {
  return <div className="admin-content"><div className="page-actions"><Button variant="secondary" onClick={onBack}>Back to transactions</Button><StatusChip tone="success">Complete</StatusChip></div><div className="detail-grid"><section className="admin-card"><h2>Transaction information</h2><div className="info-grid"><div><small>Transaction ID</small><strong>TX-260321-0847</strong></div><div><small>Patient ID</small><strong>284913</strong></div><div><small>Nurse</small><strong>Maya Chen · 48216</strong></div><div><small>Supervisor approval</small><strong>Not required</strong></div><div><small>Requested</small><strong>Today, 08:45:12</strong></div><div><small>Collected</small><strong>Today, 08:47:03</strong></div></div><h2>Items dispensed</h2><DataTable headers={["Item", "Drawer", "Quantity", "Result"]} rows={[[<strong>Sterile gauze pads</strong>, "C3", "3 units", <StatusChip tone="success">Dispensed</StatusChip>], [<strong>Adhesive dressing</strong>, "C4", "2 units", <StatusChip tone="success">Dispensed</StatusChip>], [<strong>Nitrile gloves, M</strong>, "B1", "2 units", <StatusChip tone="success">Dispensed</StatusChip>]]} /></section><section className="admin-card timeline-card"><h2>Status timeline</h2>{[["Request authorized", "08:45:12"], ["Robot started", "08:45:18"], ["Items retrieved", "08:46:24"], ["Door B2 opened", "08:46:42"], ["Items collected", "08:47:03"]].map((v, i) => <div className="timeline-row" key={v[0]}><i>{i < 4 ? "✓" : "●"}</i><div><strong>{v[0]}</strong><span>{v[1]}</span></div></div>)}</section></div></div>;
}

function Inventory({ toast }: { toast: (m: string) => void }) {
  const [view, setView] = useState<"map" | "table">("map");
  const [refill, setRefill] = useState<Supply | null>(null);
  const [qty, setQty] = useState("");
  return <div className="admin-content"><div className="page-actions"><div className="segmented"><button className={view === "map" ? "active" : ""} onClick={() => setView("map")}>Drawer map</button><button className={view === "table" ? "active" : ""} onClick={() => setView("table")}>Table view</button></div><div className="button-row"><Button variant="secondary" onClick={() => toast("Add item form opened.")}>Add item</Button><Button onClick={() => setRefill(supplies[9])}>Refill drawer</Button></div></div>
    <section className="admin-card">{view === "map" ? <div className="drawer-map">{supplies.map((s) => <button key={s.id} className={s.stock === 0 ? "empty" : s.stock < 10 ? "low" : ""} onClick={() => setRefill(s)}><div><strong>{s.drawer}</strong><StatusChip tone={s.stock === 0 ? "error" : s.stock < 10 ? "warning" : "success"}>{s.stock === 0 ? "Empty" : s.stock < 10 ? "Low" : "In stock"}</StatusChip></div><h3>{s.name}</h3><p><b>{s.stock}</b> units</p><span>Refill drawer</span></button>)}</div> : <DataTable headers={["Drawer", "Item", "Category", "Stock", "Status", ""]} rows={supplies.map((s) => [<strong>{s.drawer}</strong>, s.name, s.category, `${s.stock} units`, <StatusChip tone={s.stock < 10 ? "warning" : "success"}>{s.stock < 10 ? "Low" : "In stock"}</StatusChip>, <Button variant="ghost" onClick={() => setRefill(s)}>Edit item</Button>])} />}</section>
    {refill && <Modal title={`Refill drawer ${refill.drawer}`} onClose={() => setRefill(null)}><p>{refill.name} currently has {refill.stock} units.</p><TextField label="Quantity to add" value={qty} onChange={(v) => setQty(v.replace(/\D/g, "").slice(0, 3))} placeholder="Enter quantity" /><div className="button-row end"><Button variant="secondary" onClick={() => setRefill(null)}>Cancel</Button><Button disabled={!qty} onClick={() => { setRefill(null); setQty(""); toast("Drawer stock updated."); }}>Save</Button></div></Modal>}</div>;
}

function RobotAdmin({ toast }: { toast: (m: string) => void }) {
  const [paused, setPaused] = useState(false);
  return <div className="admin-content"><div className="dashboard-grid"><section className="admin-card"><div className="section-head"><div><h2>Robot position</h2><p>Live cabinet view</p></div><StatusChip tone={paused ? "warning" : "success"}>{paused ? "Paused" : "Working"}</StatusChip></div><CabinetDiagram active={8} label="Moving to drawer C1" /><div className="button-row"><Button variant={paused ? "primary" : "danger"} onClick={() => setPaused(!paused)}>{paused ? "Resume robot" : "Pause robot"}</Button><Button variant="secondary" onClick={() => toast("Test cycle started.")}>Run test cycle</Button></div></section><section className="admin-card"><h2>System status</h2><div className="status-list">{[["Request queue", "2 waiting", "warning"], ["Dispensing door B2", "Closed", "success"], ["Drawer sensors", "All online", "success"], ["Last maintenance", "8 Mar 2026", "neutral"]].map((v) => <div key={v[0]}><span>{v[0]}</span><StatusChip tone={v[2]}>{v[1]}</StatusChip></div>)}</div><h2>Waiting requests</h2><div className="queue-list"><div><b>1</b><span>TX-260321-0917<small>5 items · Ward 2</small></span></div><div><b>2</b><span>TX-260321-0918<small>2 items · Ward 6</small></span></div></div></section></div><section className="admin-card"><h2>Recent faults</h2><DataTable headers={["Date and time", "Fault", "Location", "Duration", "Resolution"]} rows={[["Today, 06:31", "Drawer sensor delayed", "D2", "42 sec", "Self-recovered"], ["19 Mar, 14:12", "Door obstruction", "Door B2", "3 min", "Cleared by admin"], ["17 Mar, 09:08", "Robot path blocked", "Bay C", "8 min", "Maintenance"]]} /></section></div>;
}

function Alerts() {
  const [tab, setTab] = useState("Low stock");
  const [resolved, setResolved] = useState<string[]>([]);
  const tabs = ["Low stock", "Unusual consumption", "Faults", "Reports from nurses"];
  const data: Record<string, string[]> = { "Low stock": ["Urinary catheter · Drawer E2 · 7 units", "Transparent film · Drawer D2 · 9 units"], "Unusual consumption": ["Nitrile gloves usage is 38% above expected", "10 ml syringe usage is 24% above expected"], Faults: ["Drawer D2 sensor response delayed"], "Reports from nurses": ["Door B2 was slow to open"] };
  return <div className="admin-content"><div className="tabs admin-tabs">{tabs.map((t) => <button className={tab === t ? "active" : ""} onClick={() => setTab(t)} key={t}>{t}<b>{data[t].length}</b></button>)}</div>{tab === "Unusual consumption" && <section className="admin-card consumption"><div><h2>Expected vs actual quantity</h2><p>Nitrile gloves · Ward 4 · Last 7 days</p></div><div className="bar-chart"><div><span>Expected</span><i><b style={{ width: "62%" }} /></i><strong>210</strong></div><div><span>Actual</span><i><b className="warning" style={{ width: "86%" }} /></i><strong>290</strong></div></div></section>}<section className="admin-card alert-cards">{data[tab].map((a) => <article key={a} className={resolved.includes(a) ? "resolved" : ""}><span className="alert-dot warning" /><div><StatusChip tone="warning">{tab}</StatusChip><h3>{a}</h3><p>Review this alert and take action if needed.</p><small>Today, 08:42 · ID Nurse cabinet 1</small></div><div className="button-row"><Button variant="secondary">View details</Button><Button variant="ghost" onClick={() => setResolved([...resolved, a])}>{resolved.includes(a) ? "Resolved" : "Mark as resolved"}</Button></div></article>)}</section></div>;
}

function Reports() {
  const [generated, setGenerated] = useState(false);
  const [patient, setPatient] = useState("");
  if (generated) return <div className="admin-content"><div className="page-actions"><Button variant="secondary" onClick={() => setGenerated(false)}>Back</Button><Button onClick={() => window.print()}>Download PDF</Button></div><section className="admin-card report-preview"><Logo /><h1>Insurance claim report</h1><p>Reporting period: 1–21 March 2026</p><div className="report-summary"><div><small>Total transactions</small><strong>1,842</strong></div><div><small>Items dispensed</small><strong>6,310</strong></div><div><small>Claim value</small><strong>$24,680</strong></div></div><DataTable headers={["Date", "Transaction", "Patient", "Items", "Units"]} rows={mockTransactions.map((t) => [t.time, t.id, t.patient, t.items, t.units])} /></section></div>;
  return <div className="admin-content"><section className="admin-card report-form"><div className="heading-group"><h2>Generate a report</h2><p>Choose the type and reporting period. Patient ID is optional.</p></div><div className="form-grid"><label className="field"><span>Report type</span><select><option>Insurance claim</option><option>Audit log</option><option>Consumption by ward</option></select></label><label className="field"><span>Date range</span><select><option>1–21 March 2026</option><option>Last 7 days</option><option>Last 30 days</option></select></label><TextField label="Patient ID (optional)" value={patient} onChange={(v) => setPatient(v.replace(/\D/g, "").slice(0, 8))} placeholder="Enter patient ID" /></div><Button onClick={() => setGenerated(true)}>Generate report</Button></section></div>;
}

function Users() {
  const [modal, setModal] = useState(false);
  const [id, setId] = useState("");
  const [name, setName] = useState("");
  const [users, setUsers] = useState([["Maya Chen", "48216", "Ward 4", "Nurse", "Active"], ["Elena Ruiz", "31082", "All wards", "Supervisor", "Active"], ["Omar Ali", "67149", "Ward 2", "Nurse", "Active"], ["Leah Morgan", "51730", "Ward 6", "Nurse", "Inactive"]]);
  return <div className="admin-content"><div className="page-actions"><div /><Button onClick={() => setModal(true)}>Add user</Button></div><section className="admin-card"><DataTable headers={["Name", "Staff ID", "Ward", "Role", "Status", ""]} rows={users.map((u, i) => [<strong>{u[0]}</strong>, u[1], u[2], u[3], <StatusChip tone={u[4] === "Active" ? "success" : "neutral"}>{u[4]}</StatusChip>, <Button variant="ghost" onClick={() => setUsers(users.map((x, j) => j === i ? [...x.slice(0, 4), x[4] === "Active" ? "Inactive" : "Active"] : x))}>{u[4] === "Active" ? "Deactivate" : "Activate"}</Button>])} /></section>{modal && <Modal title="Add user" onClose={() => setModal(false)}><div className="form-stack"><TextField label="Full name" value={name} onChange={setName} placeholder="Enter full name" /><TextField label="Staff ID" value={id} onChange={(v) => setId(v.replace(/\D/g, "").slice(0, 6))} placeholder="_ _ _ _ _ _" /><label className="field"><span>Ward</span><select><option>Ward 4</option><option>Ward 2</option><option>All wards</option></select></label><label className="field"><span>Role</span><select><option>Nurse</option><option>Supervisor</option></select></label></div><div className="button-row end"><Button variant="secondary" onClick={() => setModal(false)}>Cancel</Button><Button disabled={id.length < 4 || !name.trim()} onClick={() => { setUsers([...users, [name, id, "Ward 4", "Nurse", "Active"]]); setModal(false); setName(""); setId(""); }}>Save</Button></div></Modal>}</div>;
}

function Settings({ toast }: { toast: (m: string) => void }) {
  const [timeout, setTimeoutValue] = useState("2 minutes");
  const [speed, setSpeed] = useState("Standard");
  const [language, setLanguage] = useState("English");
  return <div className="admin-content"><section className="admin-card settings-form"><div className="heading-group"><h2>System settings</h2><p>Changes apply to this ID Nurse cabinet.</p></div><label className="setting-row"><div><strong>Session timeout</strong><p>Sign nurses out after a period of inactivity.</p></div><select value={timeout} onChange={(e) => setTimeoutValue(e.target.value)}><option>2 minutes</option><option>5 minutes</option><option>10 minutes</option></select></label><label className="setting-row"><div><strong>Robot speed</strong><p>Standard is recommended for routine use.</p></div><select value={speed} onChange={(e) => setSpeed(e.target.value)}><option>Standard</option><option>Reduced</option><option>Fast</option></select></label><label className="setting-row"><div><strong>Language</strong><p>Default language for the nurse kiosk.</p></div><select value={language} onChange={(e) => setLanguage(e.target.value)}><option>English</option><option>العربية</option></select></label><div className="button-row end"><Button variant="secondary" onClick={() => { setTimeoutValue("2 minutes"); setSpeed("Standard"); setLanguage("English"); }}>Reset</Button><Button onClick={() => toast("Settings saved.")}>Save changes</Button></div></section></div>;
}

export default function App() {
  const [mode, setMode] = useState<"nurse" | "admin">("nurse");
  return mode === "nurse" ? <NurseApp exitToAdmin={() => setMode("admin")} /> : <AdminApp exitToNurse={() => setMode("nurse")} />;
}
