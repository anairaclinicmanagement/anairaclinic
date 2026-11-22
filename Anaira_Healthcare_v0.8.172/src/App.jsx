import React, { useEffect, useMemo, useState } from "react";
import {
  Activity, CalendarDays, Users, Stethoscope, Pill, FlaskConical, ReceiptText,
  BedDouble, Settings, Search, Plus, Menu, X, LogOut, Wifi, WifiOff, RefreshCw,
  LayoutDashboard, ChevronRight, ShieldCheck, Clock3, HeartPulse, ClipboardList,
  Building2, UserRound, CheckCircle2, AlertTriangle
} from "lucide-react";
import { supabase, supabaseConfigured } from "./lib/supabase";
import { localStore } from "./lib/localStore";

const NAV = [
  ["Dashboard", LayoutDashboard],
  ["Patients", Users],
  ["Appointments", CalendarDays],
  ["Consultation", Stethoscope],
  ["Prescriptions", Pill],
  ["Pharmacy", Activity],
  ["Laboratory", FlaskConical],
  ["Billing", ReceiptText],
  ["IPD & Beds", BedDouble],
  ["Staff & Doctors", UserRound],
  ["Reports", ClipboardList],
  ["Settings", Settings]
];

const initialClinic = () => localStore.get("clinic", null);
const id = () => globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const today = () => new Date().toISOString().slice(0, 10);

function App() {
  const [session, setSession] = useState(null);
  const [authReady, setAuthReady] = useState(!supabaseConfigured);
  const [authMode, setAuthMode] = useState("signin");
  const [authEmail, setAuthEmail] = useState("");
  const [authPassword, setAuthPassword] = useState("");
  const [authError, setAuthError] = useState("");
  const [authBusy, setAuthBusy] = useState(false);
  const [active, setActive] = useState("Dashboard");
  const [mobileNav, setMobileNav] = useState(false);
  const [clinic, setClinic] = useState(initialClinic());
  const [clinics, setClinics] = useState([]);
  const [clinicName, setClinicName] = useState("");
  const [clinicType, setClinicType] = useState("general_opd");
  const [patients, setPatients] = useState(() => localStore.get("patients", []));
  const [appointments, setAppointments] = useState(() => localStore.get("appointments", []));
  const [patientSearch, setPatientSearch] = useState("");
  const [showPatientForm, setShowPatientForm] = useState(false);
  const [showAppointmentForm, setShowAppointmentForm] = useState(false);
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(false);
  const [online, setOnline] = useState(navigator.onLine);
  const [syncQueue, setSyncQueue] = useState(() => localStore.get("sync-queue", []));
  const [patientForm, setPatientForm] = useState({ first_name: "", last_name: "", phone: "", gender: "unknown", date_of_birth: "", notes: "" });
  const [appointmentForm, setAppointmentForm] = useState({ patient_id: "", appointment_at: `${today()}T10:00`, reason: "", visit_type: "opd" });

  useEffect(() => {
    const up = () => setOnline(true);
    const down = () => setOnline(false);
    window.addEventListener("online", up); window.addEventListener("offline", down);
    return () => { window.removeEventListener("online", up); window.removeEventListener("offline", down); };
  }, []);

  useEffect(() => {
    if (!supabaseConfigured) return;
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setAuthReady(true); });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => setSession(nextSession));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (supabaseConfigured && session?.user) loadClinics();
  }, [session?.user?.id]);

  useEffect(() => {
    if (clinic?.id && supabaseConfigured && session?.user) loadRemoteData(clinic.id);
  }, [clinic?.id, session?.user?.id]);

  useEffect(() => { localStore.set("patients", patients); }, [patients]);
  useEffect(() => { localStore.set("appointments", appointments); }, [appointments]);
  useEffect(() => { localStore.set("clinic", clinic); }, [clinic]);
  useEffect(() => { localStore.set("sync-queue", syncQueue); }, [syncQueue]);

  async function loadClinics() {
    const { data, error } = await supabase.from("clinic_members")
      .select("clinic_id, role, clinics(id,name,clinic_type)")
      .eq("user_id", session.user.id).eq("active", true);
    if (error) { setNotice(`Clinic list: ${error.message}`); return; }
    const list = (data || []).map(row => ({ ...row.clinics, role: row.role })).filter(Boolean);
    setClinics(list);
    if (!clinic && list.length) setClinic(list[0]);
    else if (clinic && list.length && !list.some(c => c.id === clinic.id)) setClinic(list[0]);
  }

  async function loadRemoteData(clinicId) {
    setLoading(true);
    try {
      const [p, a] = await Promise.all([
        supabase.from("patients").select("*").eq("clinic_id", clinicId).is("archived_at", null).order("created_at", { ascending: false }).limit(500),
        supabase.from("appointments").select("*").eq("clinic_id", clinicId).order("appointment_at", { ascending: true }).limit(500)
      ]);
      if (!p.error) setPatients(p.data || []);
      if (!a.error) setAppointments(a.data || []);
      if (p.error || a.error) setNotice(p.error?.message || a.error?.message || "Unable to load some records.");
    } finally { setLoading(false); }
  }

  async function submitAuth(e) {
    e.preventDefault(); setAuthError(""); setAuthBusy(true);
    try {
      const result = authMode === "signin"
        ? await supabase.auth.signInWithPassword({ email: authEmail, password: authPassword })
        : await supabase.auth.signUp({ email: authEmail, password: authPassword });
      if (result.error) throw result.error;
      if (authMode === "signup" && !result.data.session) setAuthError("Account created. Check your email to confirm, then sign in.");
    } catch (err) { setAuthError(err.message || "Authentication failed."); }
    finally { setAuthBusy(false); }
  }

  async function signOut() {
    if (supabase) await supabase.auth.signOut();
    setSession(null); setClinics([]); setClinic(null);
  }

  async function createClinic(e) {
    e.preventDefault();
    if (!clinicName.trim()) return;
    if (!supabaseConfigured || !session) {
      const localClinic = { id: `local-${id()}`, name: clinicName.trim(), clinic_type: clinicType, local: true };
      setClinic(localClinic); setClinics(prev => [localClinic, ...prev]); setClinicName(""); setNotice("Local clinic created on this device.");
      return;
    }
    const { data, error } = await supabase.rpc("create_clinic_with_owner", { p_name: clinicName.trim(), p_clinic_type: clinicType });
    if (error) { setNotice(`Could not create clinic: ${error.message}`); return; }
    const created = { id: data, name: clinicName.trim(), clinic_type: clinicType };
    setClinic(created); setClinics(prev => [created, ...prev]); setClinicName(""); setNotice("Clinic created successfully.");
  }

  async function savePatient(e) {
    e.preventDefault();
    if (!clinic) { setNotice("Create or select a clinic first."); return; }
    const record = {
      id: id(), clinic_id: clinic.id, uhid: `AN-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`,
      first_name: patientForm.first_name.trim(), last_name: patientForm.last_name.trim() || null,
      phone: patientForm.phone.trim() || null, gender: patientForm.gender,
      date_of_birth: patientForm.date_of_birth || null, notes: patientForm.notes.trim() || null,
      created_at: new Date().toISOString()
    };
    if (!record.first_name) return;
    if (supabaseConfigured && session && !clinic.local && online) {
      const { data, error } = await supabase.from("patients").insert({ ...record, created_by: session.user.id }).select().single();
      if (error) {
        if (online && !/fetch|network|failed to fetch/i.test(error.message || "")) { setNotice(`Patient not saved: ${error.message}`); return; }
        localStore.add("patients", record); setPatients(prev => [record, ...prev]); setSyncQueue(localStore.get("sync-queue", []));
        setNotice("Network unavailable: patient saved locally. Sync is not automatic yet.");
      } else setPatients(prev => [data, ...prev]);
    } else {
      localStore.add("patients", record); setPatients(prev => [record, ...prev]);
      setSyncQueue(localStore.get("sync-queue", []));
    }
    setPatientForm({ first_name: "", last_name: "", phone: "", gender: "unknown", date_of_birth: "", notes: "" });
    setShowPatientForm(false); setNotice("Patient record saved.");
  }

  async function saveAppointment(e) {
    e.preventDefault();
    if (!clinic) { setNotice("Create or select a clinic first."); return; }
    if (!appointmentForm.patient_id) { setNotice("Select a patient first."); return; }
    const record = {
      id: id(), clinic_id: clinic.id, patient_id: appointmentForm.patient_id,
      appointment_at: new Date(appointmentForm.appointment_at).toISOString(),
      reason: appointmentForm.reason.trim() || null, visit_type: appointmentForm.visit_type,
      status: "booked", duration_minutes: 15, created_at: new Date().toISOString()
    };
    if (supabaseConfigured && session && !clinic.local && online) {
      const { data, error } = await supabase.from("appointments").insert({ ...record, created_by: session.user.id }).select().single();
      if (error) {
        if (online && !/fetch|network|failed to fetch/i.test(error.message || "")) { setNotice(`Appointment not saved: ${error.message}`); return; }
        localStore.add("appointments", record); setAppointments(prev => [...prev, record].sort((a,b) => a.appointment_at.localeCompare(b.appointment_at))); setSyncQueue(localStore.get("sync-queue", []));
        setNotice("Network unavailable: appointment saved locally. Sync is not automatic yet.");
      } else setAppointments(prev => [...prev, data].sort((a,b) => a.appointment_at.localeCompare(b.appointment_at)));
    } else {
      localStore.add("appointments", record); setAppointments(prev => [...prev, record].sort((a,b) => a.appointment_at.localeCompare(b.appointment_at)));
      setSyncQueue(localStore.get("sync-queue", []));
    }
    setShowAppointmentForm(false); setNotice("Appointment saved.");
  }

  async function refreshData() {
    if (clinic?.id && supabaseConfigured && session && !clinic.local) await loadRemoteData(clinic.id);
    setSyncQueue(localStore.get("sync-queue", []));
    setNotice("Data refreshed. Pending offline items are shown in Sync status.");
  }

  const filteredPatients = useMemo(() => patients.filter(p => {
    if (clinic && p.clinic_id && p.clinic_id !== clinic.id) return false;
    const q = patientSearch.toLowerCase();
    return !q || `${p.first_name || ""} ${p.last_name || ""} ${p.phone || ""} ${p.uhid || ""}`.toLowerCase().includes(q);
  }), [patients, patientSearch, clinic]);
  const clinicAppointments = useMemo(() => appointments.filter(a => !clinic || !a.clinic_id || a.clinic_id === clinic.id), [appointments, clinic]);
  const upcoming = clinicAppointments.filter(a => a.appointment_at?.slice(0,10) >= today() && !["cancelled","no_show"].includes(a.status)).slice(0,6);
  const pendingSync = syncQueue.filter(item => item.status !== "synced").length;

  if (!authReady) return <div className="loading-screen"><div className="brand-mark">A</div><p>Loading Anaira Healthcare…</p></div>;
  if (supabaseConfigured && !session) return <AuthScreen mode={authMode} setMode={setAuthMode} email={authEmail} setEmail={setAuthEmail} password={authPassword} setPassword={setAuthPassword} error={authError} busy={authBusy} onSubmit={submitAuth} />;
  if (supabaseConfigured && session && clinics.length === 0 && !clinic) {
    return <SetupScreen clinicName={clinicName} setClinicName={setClinicName} clinicType={clinicType} setClinicType={setClinicType} createClinic={createClinic} signOut={signOut} />;
  }

  return (
    <div className="app-shell">
      <aside className={`sidebar ${mobileNav ? "sidebar-open" : ""}`}>
        <div className="brand"><div className="brand-mark">A</div><div><strong>Anaira</strong><span>HEALTHCARE MANAGEMENT</span></div><button className="icon-btn mobile-close" onClick={() => setMobileNav(false)}><X size={18}/></button></div>
        <div className="clinic-picker">
          <div className="clinic-avatar"><Building2 size={17}/></div>
          <div className="clinic-picker-copy"><small>ACTIVE CLINIC</small><strong>{clinic?.name || "Select or create clinic"}</strong></div>
          {clinics.length > 1 && <select aria-label="Choose clinic" value={clinic?.id || ""} onChange={e => setClinic(clinics.find(c => c.id === e.target.value) || null)}>{clinics.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}</select>}
        </div>
        <div className="nav-label">WORKSPACE</div>
        <nav>{NAV.map(([label, Icon]) => <button key={label} className={`nav-item ${active === label ? "active" : ""}`} onClick={() => { setActive(label); setMobileNav(false); }}><Icon size={18}/><span>{label}</span>{label === "Appointments" && clinicAppointments.length > 0 && <small>{clinicAppointments.length}</small>}</button>)}</nav>
        <div className="sidebar-bottom">
          <div className="offline-note"><span className={`status-dot ${online ? "is-online" : ""}`}></span><div><strong>{online ? "Online" : "Offline mode"}</strong><small>{pendingSync} pending local changes</small></div></div>
          <button className="nav-item" onClick={() => setActive("Settings")}><Settings size={18}/><span>Preferences</span></button>
          {supabaseConfigured && <button className="nav-item" onClick={signOut}><LogOut size={18}/><span>Sign out</span></button>}
        </div>
      </aside>

      {mobileNav && <button className="nav-scrim" aria-label="Close navigation" onClick={() => setMobileNav(false)} />}
      <main className="main-area">
        <header className="topbar">
          <div className="topbar-left"><button className="icon-btn mobile-menu" onClick={() => setMobileNav(true)}><Menu size={20}/></button><div><div className="breadcrumb">Workspace <ChevronRight size={14}/> <strong>{active}</strong></div><h1>{active}</h1></div></div>
          <div className="topbar-actions"><div className={`connection-pill ${online ? "online" : "offline"}`}>{online ? <Wifi size={15}/> : <WifiOff size={15}/>}<span>{online ? "Connected" : "Offline"}</span></div><button className="icon-btn" onClick={refreshData} title="Refresh data"><RefreshCw size={17}/></button><div className="user-avatar">{session?.user?.email?.[0]?.toUpperCase() || "A"}</div></div>
        </header>

        {notice && <div className="notice"><span>{notice}</span><button onClick={() => setNotice("")}><X size={15}/></button></div>}
        {!clinic && <div className="setup-card"><div className="setup-icon"><Building2/></div><div><h2>Set up your clinic</h2><p>Create a clinic workspace to start adding patients, appointments and clinical records.</p></div><form onSubmit={createClinic} className="inline-create"><input value={clinicName} onChange={e=>setClinicName(e.target.value)} placeholder="Clinic / hospital name" required/><select value={clinicType} onChange={e=>setClinicType(e.target.value)}>{clinicTypes.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select><button className="primary-btn"><Plus size={16}/> Create clinic</button></form></div>}

        {active === "Dashboard" && <Dashboard patients={filteredPatients} appointments={clinicAppointments} upcoming={upcoming} clinic={clinic} onAddPatient={()=>setShowPatientForm(true)} onAddAppointment={()=>setShowAppointmentForm(true)} onNavigate={setActive} />}
        {active === "Patients" && <PatientsPage patients={filteredPatients} search={patientSearch} setSearch={setPatientSearch} onAdd={()=>setShowPatientForm(true)} />}
        {active === "Appointments" && <AppointmentsPage appointments={clinicAppointments} patients={patients} onAdd={()=>setShowAppointmentForm(true)} />}
        {!["Dashboard","Patients","Appointments"].includes(active) && <ModulePage active={active} onNavigate={setActive} />}
        <footer className="footer"><span>© {new Date().getFullYear()} Anaira Healthcare</span><span><ShieldCheck size={13}/> Clinic data is access-controlled by Supabase RLS when cloud-connected.</span><span>v0.1.0</span></footer>
      </main>

      {showPatientForm && <Modal title="Register new patient" onClose={()=>setShowPatientForm(false)}><form className="form-grid" onSubmit={savePatient}><label>First name *<input required value={patientForm.first_name} onChange={e=>setPatientForm({...patientForm,first_name:e.target.value})}/></label><label>Last name<input value={patientForm.last_name} onChange={e=>setPatientForm({...patientForm,last_name:e.target.value})}/></label><label>Phone number<input inputMode="tel" value={patientForm.phone} onChange={e=>setPatientForm({...patientForm,phone:e.target.value})}/></label><label>Gender<select value={patientForm.gender} onChange={e=>setPatientForm({...patientForm,gender:e.target.value})}><option value="unknown">Not specified</option><option value="female">Female</option><option value="male">Male</option><option value="other">Other</option></select></label><label>Date of birth<input type="date" value={patientForm.date_of_birth} onChange={e=>setPatientForm({...patientForm,date_of_birth:e.target.value})}/></label><label className="span-2">Notes<textarea rows="3" value={patientForm.notes} onChange={e=>setPatientForm({...patientForm,notes:e.target.value})}/></label><div className="modal-actions"><button type="button" className="secondary-btn" onClick={()=>setShowPatientForm(false)}>Cancel</button><button className="primary-btn"><Plus size={16}/> Save patient</button></div></form></Modal>}
      {showAppointmentForm && <Modal title="Book appointment" onClose={()=>setShowAppointmentForm(false)}><form className="form-grid" onSubmit={saveAppointment}><label className="span-2">Patient *<select required value={appointmentForm.patient_id} onChange={e=>setAppointmentForm({...appointmentForm,patient_id:e.target.value})}><option value="">Select patient</option>{patients.map(p=><option key={p.id} value={p.id}>{p.first_name} {p.last_name||""} · {p.uhid||"Local"}</option>)}</select></label><label className="span-2">Date and time *<input type="datetime-local" required value={appointmentForm.appointment_at} onChange={e=>setAppointmentForm({...appointmentForm,appointment_at:e.target.value})}/></label><label>Visit type<select value={appointmentForm.visit_type} onChange={e=>setAppointmentForm({...appointmentForm,visit_type:e.target.value})}><option value="opd">OPD</option><option value="follow_up">Follow-up</option><option value="procedure">Procedure</option><option value="teleconsultation">Teleconsultation</option><option value="emergency">Emergency</option></select></label><label>Reason<input value={appointmentForm.reason} onChange={e=>setAppointmentForm({...appointmentForm,reason:e.target.value})}/></label><div className="modal-actions"><button type="button" className="secondary-btn" onClick={()=>setShowAppointmentForm(false)}>Cancel</button><button className="primary-btn"><CalendarDays size={16}/> Book appointment</button></div></form></Modal>}
    </div>
  );
}

const clinicTypes = [
  {value:"general_opd",label:"General OPD"},{value:"dental",label:"Dental clinic"},{value:"eye",label:"Eye clinic"},
  {value:"skin",label:"Skin / Dermatology"},{value:"pediatrics",label:"Pediatrics"},{value:"gynecology",label:"Gynecology"},
  {value:"orthopedic",label:"Orthopedic"},{value:"ayurveda",label:"Ayurveda"},{value:"homeopathy",label:"Homeopathy"},
  {value:"physiotherapy",label:"Physiotherapy"},{value:"diagnostic_lab",label:"Diagnostic lab"},{value:"polyclinic",label:"Polyclinic"},
  {value:"hospital",label:"Hospital / IPD"},{value:"other",label:"Other"}
];

function AuthScreen({mode,setMode,email,setEmail,password,setPassword,error,busy,onSubmit}) {
  return <div className="auth-screen"><div className="auth-panel"><div className="brand auth-brand"><div className="brand-mark">A</div><div><strong>Anaira</strong><span>HEALTHCARE MANAGEMENT</span></div></div><div className="auth-kicker">CLINICAL WORKSPACE</div><h1>{mode==="signin"?"Welcome back":"Create your account"}</h1><p className="muted">Secure access to your clinic workspace.</p><form onSubmit={onSubmit} className="auth-form"><label>Email address<input type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@clinic.com"/></label><label>Password<input type="password" autoComplete={mode==="signin"?"current-password":"new-password"} minLength="8" required value={password} onChange={e=>setPassword(e.target.value)} placeholder="At least 8 characters"/></label>{error&&<div className="error-box">{error}</div>}<button className="primary-btn auth-submit" disabled={busy}>{busy?"Please wait…":mode==="signin"?"Sign in":"Create account"}</button></form><p className="auth-switch">{mode==="signin"?"New to Anaira Healthcare?":"Already registered?"} <button onClick={()=>setMode(mode==="signin"?"signup":"signin")}>{mode==="signin"?"Create account":"Sign in"}</button></p><div className="auth-foot"><ShieldCheck size={15}/> Secure sign-in for authorized clinic staff</div></div><div className="auth-aside"><div className="aside-orb orb-one"/><div className="aside-orb orb-two"/><div className="aside-content"><div className="aside-icon"><HeartPulse size={32}/></div><h2>Care coordination,<br/>made simpler.</h2><p>Patient records, appointments and clinic operations in one organized workspace.</p><div className="aside-features"><span><CheckCircle2/> Patient-centric records</span><span><CheckCircle2/> Access your clinic workspace</span><span><CheckCircle2/> Clinic and hospital operations</span></div></div></div></div>;
}

function SetupScreen({clinicName,setClinicName,clinicType,setClinicType,createClinic,signOut}) {
  return <div className="setup-screen"><div className="setup-card setup-centered"><div className="setup-icon"><Building2 size={25}/></div><div><div className="auth-kicker">FIRST-TIME SETUP</div><h1>Create your clinic workspace</h1><p className="muted">Your signed-in account will become the owner of this clinic.</p></div><form onSubmit={createClinic} className="setup-form"><label>Clinic / hospital name<input required value={clinicName} onChange={e=>setClinicName(e.target.value)} placeholder="e.g. Anaira Family Clinic"/></label><label>Clinic type<select value={clinicType} onChange={e=>setClinicType(e.target.value)}>{clinicTypes.map(t=><option key={t.value} value={t.value}>{t.label}</option>)}</select></label><button className="primary-btn"><Plus size={16}/> Create clinic</button><button type="button" className="text-btn" onClick={signOut}>Sign out</button></form></div></div>;
}

function Dashboard({patients,appointments,upcoming,clinic,onAddPatient,onAddAppointment,onNavigate}) {
  const todayAppointments = appointments.filter(a=>a.appointment_at?.slice(0,10)===today() && !["cancelled","no_show"].includes(a.status));
  const stats = [
    {label:"Registered patients",value:patients.length,detail:"Visible in this workspace",icon:Users,tone:"mint"},
    {label:"Appointments today",value:todayAppointments.length,detail:"Scheduled visits",icon:CalendarDays,tone:"blue"},
    {label:"Upcoming appointments",value:appointments.filter(a=>a.appointment_at?.slice(0,10)>=today()).length,detail:"Including today",icon:Clock3,tone:"gold"},
    {label:"Clinic workspace",value:clinic?"Ready":"Setup needed",detail:clinic?.clinic_type?.replaceAll("_"," ")||"Create a clinic",icon:Building2,tone:"purple"}
  ];
  return <div className="page-content"><div className="welcome-row"><div><div className="auth-kicker">CLINIC OVERVIEW</div><h2>{clinic ? `Good day, ${clinic.name}` : "Welcome to Anaira Healthcare"}</h2><p className="muted">Today’s clinic activity at a glance.</p></div><div className="quick-actions"><button className="secondary-btn" onClick={onAddPatient}><Plus size={16}/> Add patient</button><button className="primary-btn" onClick={onAddAppointment}><CalendarDays size={16}/> Book appointment</button></div></div>
    <div className="stats-grid">{stats.map(s=><div className="stat-card" key={s.label}><div className={`stat-icon ${s.tone}`}><s.icon size={19}/></div><div className="stat-label">{s.label}</div><div className="stat-value">{s.value}</div><div className="stat-detail">{s.detail}</div></div>)}</div>
    <div className="dashboard-grid"><section className="panel appointments-panel"><div className="panel-heading"><div><h3>Upcoming appointments</h3><p>Next scheduled patient visits</p></div><button className="link-btn" onClick={()=>onNavigate("Appointments")}>View all <ChevronRight size={15}/></button></div>{upcoming.length===0?<EmptyState icon={CalendarDays} title="No appointments yet" text="Book an appointment to start your daily queue." action="Book appointment" onAction={onAddAppointment}/>:<div className="appointment-list">{upcoming.map(a=><AppointmentRow key={a.id} appointment={a} patients={patients}/>)}</div>}</section>
    <section className="panel shortcuts-panel"><div className="panel-heading"><div><h3>Quick access</h3><p>Common clinic tasks</p></div></div><div className="shortcut-grid"><Shortcut icon={Users} title="Patients" text="Register and find records" onClick={()=>onNavigate("Patients")}/><Shortcut icon={Stethoscope} title="Consultation" text="Clinical notes and vitals" onClick={()=>onNavigate("Consultation")}/><Shortcut icon={Pill} title="Prescriptions" text="Medication instructions" onClick={()=>onNavigate("Prescriptions")}/><Shortcut icon={ReceiptText} title="Billing" text="Invoices and payments" onClick={()=>onNavigate("Billing")}/></div></section></div>
    <div className="info-banner"><div className="info-icon"><ShieldCheck size={20}/></div><div><strong>Protect patient information</strong><p>Give each staff member an individual account, grant only the access they need, and keep regular backups of clinic records.</p></div></div>
  </div>;
}

function PatientsPage({patients,search,setSearch,onAdd}) {
  return <div className="page-content"><div className="section-toolbar"><div><h2>Patient directory</h2><p className="muted">Manage patient identities and contact details.</p></div><button className="primary-btn" onClick={onAdd}><Plus size={16}/> Register patient</button></div><div className="table-panel"><div className="table-toolbar"><div className="search-box"><Search size={17}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search name, phone or UHID"/></div><span className="result-count">{patients.length} records</span></div>{patients.length===0?<EmptyState icon={Users} title="No patients found" text="Register a patient to create the first record." action="Register patient" onAction={onAdd}/>:<div className="table-scroll"><table><thead><tr><th>Patient</th><th>UHID</th><th>Phone</th><th>Gender</th><th>Date added</th></tr></thead><tbody>{patients.map(p=><tr key={p.id}><td><div className="person-cell"><div className="person-avatar">{(p.first_name||"P")[0].toUpperCase()}</div><div><strong>{p.first_name} {p.last_name||""}</strong><small>{p.email||"Patient record"}</small></div></div></td><td><span className="uhid">{p.uhid||"Local record"}</span></td><td>{p.phone||"—"}</td><td><span className="soft-tag">{p.gender||"unknown"}</span></td><td>{p.created_at?new Date(p.created_at).toLocaleDateString():"—"}</td></tr>)}</tbody></table></div>}</div></div>;
}

function AppointmentsPage({appointments,patients,onAdd}) {
  const sorted=[...appointments].sort((a,b)=>(a.appointment_at||"").localeCompare(b.appointment_at||""));
  return <div className="page-content"><div className="section-toolbar"><div><h2>Appointment schedule</h2><p className="muted">Manage OPD visits and follow-up bookings.</p></div><button className="primary-btn" onClick={onAdd}><Plus size={16}/> Book appointment</button></div><div className="table-panel"><div className="table-toolbar"><span className="result-count">{appointments.length} appointments</span><span className="soft-tag">Timezone: Asia/Kolkata</span></div>{sorted.length===0?<EmptyState icon={CalendarDays} title="No appointments scheduled" text="Create an appointment and it will appear here." action="Book appointment" onAction={onAdd}/>:<div className="table-scroll"><table><thead><tr><th>Date & time</th><th>Patient</th><th>Visit type</th><th>Reason</th><th>Status</th></tr></thead><tbody>{sorted.map(a=>{const p=patients.find(x=>x.id===a.patient_id);return <tr key={a.id}><td><strong>{a.appointment_at?new Date(a.appointment_at).toLocaleString():"—"}</strong></td><td>{p?`${p.first_name} ${p.last_name||""}`:"Patient record"}</td><td>{(a.visit_type||"opd").replaceAll("_"," ")}</td><td>{a.reason||"—"}</td><td><span className={`status-tag ${(a.status||"booked").replaceAll("_","-")}`}>{a.status||"booked"}</span></td></tr>})}</tbody></table></div>}</div></div>;
}

function ModulePage({active,onNavigate}) {
  const moduleInfo = {
    "Consultation": {icon:Stethoscope,title:"Consultation & EMR",description:"Record consultations, vital signs, diagnoses, treatment plans and clinical notes.",items:["Patient encounter workspace","Vitals capture","Diagnosis and clinical notes","Encounter sign-off"],status:"Available"},
    "Prescriptions": {icon:Pill,title:"Prescriptions",description:"Create structured medication instructions linked to a patient encounter.",items:["Prescription header and items","Dose, route, frequency and duration","Printable prescription workflow","Dispensing status"],status:"Available"},
    "Pharmacy": {icon:Activity,title:"Pharmacy & inventory",description:"Manage medicine catalogue, batches, expiry dates and stock levels.",items:["Medicine catalogue","Batch and expiry dates","Stock and reorder level","Dispensing workflow"],status:"Available"},
    "Laboratory": {icon:FlaskConical,title:"Laboratory",description:"Lab catalogue, orders, specimens and result capture.",items:["Test catalogue","Lab orders and status","Numeric/text results","Abnormal result flags"],status:"Available"},
    "Billing": {icon:ReceiptText,title:"Billing & payments",description:"Service catalogue, invoices, invoice items and payment records.",items:["Service price list","Invoice line items","Cash / card / UPI payments","Insurance claim tracking"],status:"Available"},
    "IPD & Beds": {icon:BedDouble,title:"IPD, wards & beds",description:"Hospital admissions, rooms and bed capacity records.",items:["Ward and room setup","Admission / discharge status","Admitting doctor","Discharge summary"],status:"Available"},
    "Staff & Doctors": {icon:UserRound,title:"Staff & doctor management",description:"Clinic members, staff profiles, roles and weekly doctor schedules.",items:["Role-aware clinic membership","Doctor profile and registration","Weekly schedules","Multi-branch staff"],status:"Available"},
    "Reports": {icon:ClipboardList,title:"Reports & audit",description:"Review activity logs and operational reports.",items:["Audit events","Patient and appointment reporting","Billing summaries","Sync queue health"],status:"Available"},
    "Settings": {icon:Settings,title:"Clinic settings",description:"Manage clinic profile, branch setup, preferences and connectivity.",items:["Clinic and branch setup","Clinic type and timezone","Offline queue status","Supabase connection settings"],status:"Setup"}
  }[active] || {icon:Activity,title:active,description:"Manage clinic workflow records.",items:["Clinic records","Access-controlled clinic records","Workflow tools"],status:"Available"};
  const Icon=moduleInfo.icon;
  return <div className="page-content"><div className="module-hero"><div className="module-icon"><Icon size={27}/></div><div><div className="auth-kicker">ANAIRA CLINIC MODULE</div><h2>{moduleInfo.title}</h2><p>{moduleInfo.description}</p><span className="soft-tag"><CheckCircle2 size={13}/> {moduleInfo.status}</span></div></div><div className="module-grid">{moduleInfo.items.map((item,i)=><div className="module-feature" key={item}><div className="feature-number">{String(i+1).padStart(2,"0")}</div><div><strong>{item}</strong><p>View and manage this area of your clinic workflow.</p></div></div>)}</div><div className="warning-banner"><AlertTriangle size={18}/><div><strong>Module guidance</strong><p>Only use the actions available on this screen. Confirm clinical records, payments and user permissions before relying on them for patient care.</p></div></div><button className="secondary-btn" onClick={()=>onNavigate("Dashboard")}>Back to dashboard</button></div>;
}

function AppointmentRow({appointment,patients}) {
  const p=patients.find(x=>x.id===appointment.patient_id);
  const dt=appointment.appointment_at?new Date(appointment.appointment_at):null;
  return <div className="appointment-row"><div className="time-block"><strong>{dt?dt.toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"}):"—"}</strong><small>{dt?dt.toLocaleDateString([],{day:"2-digit",month:"short"}):""}</small></div><div className="appointment-person"><div className="person-avatar">{(p?.first_name||"P")[0].toUpperCase()}</div><div><strong>{p?`${p.first_name} ${p.last_name||""}`:"Patient record"}</strong><small>{appointment.reason||"General consultation"}</small></div></div><span className={`status-tag ${(appointment.status||"booked").replaceAll("_","-")}`}>{appointment.status||"booked"}</span></div>;
}

function Shortcut({icon:Icon,title,text,onClick}) { return <button className="shortcut" onClick={onClick}><div className="shortcut-icon"><Icon size={19}/></div><div><strong>{title}</strong><small>{text}</small></div><ChevronRight size={16} className="shortcut-chevron"/></button>; }
function EmptyState({icon:Icon,title,text,action,onAction}) { return <div className="empty-state"><div className="empty-icon"><Icon size={23}/></div><strong>{title}</strong><p>{text}</p>{action&&<button className="secondary-btn" onClick={onAction}><Plus size={15}/>{action}</button>}</div>; }
function Modal({title,onClose,children}) { return <div className="modal-backdrop" role="presentation" onMouseDown={e=>{if(e.target===e.currentTarget)onClose();}}><section className="modal" role="dialog" aria-modal="true" aria-label={title}><div className="modal-heading"><h2>{title}</h2><button className="icon-btn" onClick={onClose}><X size={18}/></button></div>{children}</section></div>; }

export default App;
