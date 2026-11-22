
'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  CalendarPlus,
  ClipboardPlus,
  CreditCard,
  FlaskConical,
  Plus,
  Users,
  Wallet,
  Pill,
  Activity,
  Building2,
  Bed,
  Stethoscope,
  ArrowUpRight,
  Clock3,
  ReceiptText,
  HeartPulse,
} from 'lucide-react';

import { supabase } from '@/lib/supabase';
import { getActiveClinicId } from '@/lib/clinic';

type Appointment = {
  id: string;
  appointment_at: string;
  patient_id: string;
  visit_type: string;
  status: string;
  patients?: {
    first_name: string;
    last_name: string;
    uhid: string;
  } | null;
};

function getGreeting(): string {
  const hour = new Date().getHours();

  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';

  return 'Good night';
}

export default function Dashboard() {
  const [greeting, setGreeting] = useState('Welcome');
  const [clinicName, setClinicName] = useState('Clinic workspace');
  const [patients, setPatients] = useState(0);
  const [todayAppointments, setTodayAppointments] = useState(0);
  const [invoiceTotal, setInvoiceTotal] = useState(0);
  const [dueTotal, setDueTotal] = useState(0);
  const [activeAdmissions, setActiveAdmissions] = useState(0);
  const [activeBeds, setActiveBeds] = useState(0);
  const [occupiedBeds, setOccupiedBeds] = useState(0);
  const [nextAppointments, setNextAppointments] = useState<Appointment[]>([]);
  const [message, setMessage] = useState('');

  // Automatically update the greeting using the device's local time.
  useEffect(() => {
    const updateGreeting = () => {
      setGreeting(getGreeting());
    };

    updateGreeting();

    const interval = window.setInterval(updateGreeting, 60_000);

    return () => window.clearInterval(interval);
  }, []);

  // Load data for the currently active clinic.
  useEffect(() => {
    let cancelled = false;

    async function loadDashboard() {
      if (!supabase) {
        if (!cancelled) {
          setMessage(
            'Supabase is not configured. Check .env.local and restart Next.js.'
          );
        }
        return;
      }

      try {
        const {
          data: { user },
          error: authError,
        } = await supabase.auth.getUser();

        if (cancelled) return;

        if (authError) {
          setMessage(authError.message);
          return;
        }

        if (!user) {
          setMessage(
            'Sign in or create a clinic workspace to load live clinic data.'
          );
          return;
        }

        const clinicId = getActiveClinicId();

        if (!clinicId) {
          setMessage(
            'No clinic selected. Open Setup / Sign in to create or select a workspace.'
          );
          return;
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const [
          { data: clinic, error: clinicError },
          { count: patientCount, error: patientError },
          { data: appointments, error: appointmentError },
          { data: invoices, error: invoiceError },
          { data: admissions, error: admissionsError },
          { data: beds, error: bedsError },
        ] = await Promise.all([
          supabase
            .from('clinics')
            .select('name')
            .eq('id', clinicId)
            .maybeSingle(),

          supabase
            .from('patients')
            .select('id', { count: 'exact', head: true })
            .eq('clinic_id', clinicId)
            .is('archived_at', null),

          supabase
            .from('appointments')
            .select(
              'id, appointment_at, patient_id, visit_type, status, patients(first_name, last_name, uhid)'
            )
            .eq('clinic_id', clinicId)
            .gte('appointment_at', today.toISOString())
            .lt('appointment_at', tomorrow.toISOString())
            .order('appointment_at')
            .limit(100),

          supabase
            .from('invoices')
            .select('total_amount, paid_amount, consolidated_into_invoice_id, status')
            .eq('clinic_id', clinicId)
            .limit(1000),

          supabase
            .from('admissions')
            .select('id, status, bed_id')
            .eq('clinic_id', clinicId)
            .in('status', ['admitted', 'transferred'])
            .limit(1000),

          supabase
            .from('room_beds')
            .select('id, active')
            .eq('clinic_id', clinicId)
            .eq('active', true)
            .limit(2000),
        ]);

        if (cancelled) return;

        if (clinicError) {
          setMessage(clinicError.message);
        } else if (clinic?.name) {
          setClinicName(clinic.name);
        }

        if (patientError) {
          setMessage(patientError.message);
        } else {
          setPatients(patientCount ?? 0);
        }

        if (appointmentError) {
          setMessage(appointmentError.message);
        } else {
          setNextAppointments(
            (appointments ?? []) as unknown as Appointment[]
          );
          setTodayAppointments(appointments?.length ?? 0);
        }

        if (admissionsError) setMessage(admissionsError.message);
        else setActiveAdmissions(admissions?.length ?? 0);

        if (bedsError) setMessage(bedsError.message);
        else {
          setActiveBeds(beds?.length ?? 0);
          const occupied = new Set((admissions ?? []).map((a) => a.bed_id).filter(Boolean));
          setOccupiedBeds(occupied.size);
        }

        if (invoiceError) {
          setMessage(invoiceError.message);
        } else {
          // Consolidated source invoices are already represented by their
          // final invoice. Exclude them from dashboard totals to prevent
          // double-counting the same IPD charges.
          const billableInvoices = (invoices ?? []).filter(
            (invoice) =>
              !invoice.consolidated_into_invoice_id &&
              invoice.status !== 'cancelled' &&
              invoice.status !== 'void'
          );

          setInvoiceTotal(
            billableInvoices.reduce(
              (sum, invoice) => sum + Number(invoice.total_amount || 0),
              0
            )
          );

          setDueTotal(
            billableInvoices.reduce(
              (sum, invoice) =>
                sum +
                Math.max(
                  0,
                  Number(invoice.total_amount || 0) -
                    Number(invoice.paid_amount || 0)
                ),
              0
            )
          );
        }
      } catch (error) {
        if (!cancelled) {
          setMessage(
            error instanceof Error
              ? error.message
              : 'Unable to load clinic dashboard data.'
          );
        }
      }
    }

    void loadDashboard();

    return () => {
      cancelled = true;
    };
  }, []);

  const formatCurrency = (value: number) => `₹${value.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
  const todayLabel = new Date().toLocaleDateString('en-IN', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' });

  return (
    <div className="premium-dashboard">
      <section className="dash-hero">
        <div className="dash-hero-copy">
          <span className="dash-kicker"><HeartPulse size={14}/> ANAIRA HEALTHCARE · CLINIC OVERVIEW</span>
          <h1>{greeting}, {clinicName}</h1>
          <p>Your hospital at a glance — patient care, daily operations and financial performance.</p>
          <div className="dash-hero-meta"><span><Clock3 size={14}/>{todayLabel}</span><span className="dash-live"><i/> Live clinic data</span></div>
        </div>
        <div className="dash-hero-actions">
          <Link href="/appointments" className="dash-outline"><CalendarPlus size={16}/> Appointments</Link>
          <Link href="/patients" className="dash-primary"><Plus size={16}/> Register patient</Link>
        </div>
        <div className="dash-hero-art"><div className="dash-orbit orbit-one"/><div className="dash-orbit orbit-two"/><div className="dash-cross">+</div><HeartPulse size={82}/></div>
      </section>

      {message && <div className="notice">{message}</div>}

      <div className="dash-section-head"><div><span>PERFORMANCE SNAPSHOT</span><h2>Today&apos;s overview</h2></div><small>Clinic-scoped live records</small></div>
      <section className="dash-kpi-grid">
        <article className="dash-kpi kpi-blue"><div className="dash-kpi-top"><span>Total patients</span><i><Users size={19}/></i></div><strong>{patients.toLocaleString('en-IN')}</strong><small>Active patient records</small><Link href="/patients">View patients <ArrowUpRight size={13}/></Link></article>
        <article className="dash-kpi kpi-violet"><div className="dash-kpi-top"><span>Today&apos;s appointments</span><i><CalendarPlus size={19}/></i></div><strong>{todayAppointments}</strong><small>Scheduled for today</small><Link href="/appointments">Open schedule <ArrowUpRight size={13}/></Link></article>
        <article className="dash-kpi kpi-teal"><div className="dash-kpi-top"><span>Active IPD admissions</span><i><Bed size={19}/></i></div><strong>{activeAdmissions}</strong><small>Currently admitted patients</small><Link href="/ipd">Open IPD <ArrowUpRight size={13}/></Link></article>
        <article className="dash-kpi kpi-green"><div className="dash-kpi-top"><span>Available beds</span><i><Stethoscope size={19}/></i></div><strong>{Math.max(0, activeBeds - occupiedBeds)}</strong><small>{occupiedBeds} occupied · {activeBeds} active beds</small><Link href="/ipd">Manage beds <ArrowUpRight size={13}/></Link></article>
        <article className="dash-kpi kpi-gold"><div className="dash-kpi-top"><span>Invoice value</span><i><Wallet size={19}/></i></div><strong>{formatCurrency(invoiceTotal)}</strong><small>Non-cancelled invoices</small><Link href="/billing">View billing <ArrowUpRight size={13}/></Link></article>
        <article className="dash-kpi kpi-rose"><div className="dash-kpi-top"><span>Outstanding dues</span><i><CreditCard size={19}/></i></div><strong>{formatCurrency(dueTotal)}</strong><small>Pending collection balance</small><Link href="/billing">Collect payment <ArrowUpRight size={13}/></Link></article>
      </section>

      <section className="dash-main-grid">
        <div className="dash-panel dash-appointments">
          <div className="dash-panel-head"><div><span>DAILY SCHEDULE</span><h2>Today&apos;s appointments</h2><p>Upcoming patient visits for this clinic</p></div><Link href="/appointments">View all <ArrowUpRight size={14}/></Link></div>
          <div className="dash-appointment-list">
            {nextAppointments.slice(0, 7).map((appointment) => {
              const patient = appointment.patients;
              const name = [patient?.first_name, patient?.last_name].filter(Boolean).join(' ') || 'Patient';
              return <div className="dash-appointment-row" key={appointment.id}><div className="dash-time">{new Date(appointment.appointment_at).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'})}</div><div className="dash-avatar">{name.slice(0,1).toUpperCase()}</div><div className="dash-patient"><b>{name}</b><small>{patient?.uhid || 'UHID pending'} · {appointment.visit_type || 'Consultation'}</small></div><span className={`dash-status ${appointment.status.toLowerCase()==='completed'?'done':''}`}>{appointment.status}</span></div>;
            })}
            {nextAppointments.length===0 && <div className="dash-empty"><CalendarPlus size={25}/><b>No appointments scheduled</b><span>There are no visits in today&apos;s schedule.</span><Link href="/appointments">Book an appointment</Link></div>}
          </div>
        </div>
        <div className="dash-side-stack">
          <div className="dash-panel dash-quick-panel"><div className="dash-panel-head"><div><span>SHORTCUTS</span><h2>Quick actions</h2></div></div><div className="dash-action-grid">
            <Link href="/patients"><i><Users size={18}/></i><b>New patient</b><small>Register profile</small></Link>
            <Link href="/appointments"><i><CalendarPlus size={18}/></i><b>Book visit</b><small>Manage schedule</small></Link>
            <Link href="/opd"><i><ClipboardPlus size={18}/></i><b>OPD desk</b><small>Patient consultation</small></Link>
            <Link href="/ipd"><i><Bed size={18}/></i><b>IPD admission</b><small>Ward &amp; bed management</small></Link>
            <Link href="/billing"><i><ReceiptText size={18}/></i><b>Create invoice</b><small>Billing &amp; payments</small></Link>
            <Link href="/laboratory"><i><FlaskConical size={18}/></i><b>Lab orders</b><small>Tests &amp; results</small></Link>
            <Link href="/pharmacy"><i><Pill size={18}/></i><b>Pharmacy</b><small>Stock &amp; dispensing</small></Link>
            <Link href="/reports"><i><Activity size={18}/></i><b>Reports</b><small>Clinic performance</small></Link>
          </div></div>
          <div className="dash-panel dash-collection-panel"><div className="dash-panel-head"><div><span>REVENUE MONITOR</span><h2>Billing summary</h2></div><Link href="/billing">Details <ArrowUpRight size={13}/></Link></div><div className="dash-money-row"><span>Invoice value</span><b>{formatCurrency(invoiceTotal)}</b></div><div className="dash-money-row"><span>Outstanding</span><b className="money-due">{formatCurrency(dueTotal)}</b></div><div className="dash-collection-track"><i style={{width:`${invoiceTotal>0?Math.max(0,Math.min(100,((invoiceTotal-dueTotal)/invoiceTotal)*100)):0}%`}}/></div><small className="dash-collection-caption">{invoiceTotal>0?`${Math.round(Math.max(0,Math.min(100,((invoiceTotal-dueTotal)/invoiceTotal)*100)))}% collected against invoice value`:'No invoice collection data yet'}</small></div>
        </div>
      </section>
      <section className="dash-footer-strip"><div><i><Activity size={18}/></i><span><b>Clinic operations at a glance</b><small>Use the shortcuts to move directly to patient care and hospital workflows.</small></span></div><Link href="/reports">Open reports <ArrowUpRight size={14}/></Link></section>
    </div>
  );
}
