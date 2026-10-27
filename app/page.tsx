
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
            .select('total_amount, paid_amount')
            .eq('clinic_id', clinicId)
            .limit(1000),
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

        if (invoiceError) {
          setMessage(invoiceError.message);
        } else {
          setInvoiceTotal(
            (invoices ?? []).reduce(
              (sum, invoice) => sum + Number(invoice.total_amount || 0),
              0
            )
          );

          setDueTotal(
            (invoices ?? []).reduce(
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

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="eyebrow">
            ANAIRA HEALTHCARE · LIVE WORKSPACE
          </div>

          <h1>
            {greeting}, {clinicName}
          </h1>

          <p>
            Your clinic&apos;s patients, appointments and billing
            at a glance.
          </p>
        </div>

        <Link href="/patients" className="primary-button">
          <Plus size={16} />
          Register patient
        </Link>
      </div>

      {message && <div className="notice">{message}</div>}

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-top">
            Total patients
            <span className="stat-icon">
              <Users size={17} />
            </span>
          </div>

          <div className="stat-value">
            {patients.toLocaleString('en-IN')}
          </div>

          <div className="stat-foot">Active patient records</div>
        </div>

        <div className="stat-card">
          <div className="stat-top">
            Today&apos;s appointments
            <span className="stat-icon blue">
              <CalendarPlus size={17} />
            </span>
          </div>

          <div className="stat-value">{todayAppointments}</div>

          <div className="stat-foot">Scheduled today</div>
        </div>

        <div className="stat-card">
          <div className="stat-top">
            Invoice total
            <span className="stat-icon gold">
              <Wallet size={17} />
            </span>
          </div>

          <div className="stat-value">
            ₹{invoiceTotal.toLocaleString('en-IN')}
          </div>

          <div className="stat-foot">From loaded invoices</div>
        </div>

        <div className="stat-card">
          <div className="stat-top">
            Outstanding balance
            <span className="stat-icon rose">
              <CreditCard size={17} />
            </span>
          </div>

          <div className="stat-value">
            ₹{dueTotal.toLocaleString('en-IN')}
          </div>

          <div className="stat-foot">
            Invoice total less recorded payments
          </div>
        </div>
      </div>

      <div className="content-grid">
        <div>
          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>Today&apos;s appointments</h2>
                <p>Schedule for your active clinic</p>
              </div>

              <Link className="text-link" href="/appointments">
                View schedule →
              </Link>
            </div>

            <div className="appointment-list">
              {nextAppointments.map((appointment) => {
                const patient = appointment.patients;

                return (
                  <div
                    className="appointment-row"
                    key={appointment.id}
                  >
                    <div className="time-block">
                      {new Date(
                        appointment.appointment_at
                      ).toLocaleTimeString('en-IN', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </div>

                    <div className="patient-avatar green">
                      {(patient?.first_name || 'P').slice(0, 1)}
                      {(patient?.last_name || '').slice(0, 1)}
                    </div>

                    <div className="patient-info">
                      <b>
                        {[
                          patient?.first_name,
                          patient?.last_name,
                        ]
                          .filter(Boolean)
                          .join(' ') || 'Patient'}
                      </b>

                      <small>
                        {patient?.uhid || ''}
                        {' · '}
                        {appointment.visit_type}
                      </small>
                    </div>

                    <span className="tag waiting">
                      {appointment.status}
                    </span>
                  </div>
                );
              })}

              {nextAppointments.length === 0 && (
                <div className="table-empty">
                  No appointments scheduled for today.
                </div>
              )}
            </div>
          </section>
        </div>

        <div>
          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>Quick actions</h2>
                <p>Clinic operations</p>
              </div>
            </div>

            <div className="quick-grid">
              <Link className="quick-action" href="/patients">
                <span className="quick-icon">
                  <Users size={17} />
                </span>
                <span>
                  <b>New patient</b>
                  <small>Register profile</small>
                </span>
              </Link>

              <Link className="quick-action" href="/appointments">
                <span className="quick-icon">
                  <CalendarPlus size={17} />
                </span>
                <span>
                  <b>Book appointment</b>
                  <small>Schedule a visit</small>
                </span>
              </Link>

              <Link className="quick-action" href="/consultation">
                <span className="quick-icon">
                  <ClipboardPlus size={17} />
                </span>
                <span>
                  <b>Consultation</b>
                  <small>Clinical notes &amp; vitals</small>
                </span>
              </Link>

              <Link className="quick-action" href="/billing">
                <span className="quick-icon">
                  <CreditCard size={17} />
                </span>
                <span>
                  <b>Create bill</b>
                  <small>Invoice &amp; collection</small>
                </span>
              </Link>

              <Link className="quick-action" href="/pharmacy">
                <span className="quick-icon">
                  <Pill size={17} />
                </span>
                <span>
                  <b>Pharmacy</b>
                  <small>Batch stock &amp; expiry</small>
                </span>
              </Link>

              <Link className="quick-action" href="/laboratory">
                <span className="quick-icon">
                  <FlaskConical size={17} />
                </span>
                <span>
                  <b>Laboratory</b>
                  <small>Tests, orders, results</small>
                </span>
              </Link>

              <Link className="quick-action" href="/settings">
                <span className="quick-icon">
                  <Building2 size={17} />
                </span>
                <span>
                  <b>Clinic settings</b>
                  <small>Readiness &amp; modules</small>
                </span>
              </Link>
            </div>
          </section>

          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>System readiness</h2>
                <p>Be aware of unfinished capabilities</p>
              </div>

              <Activity size={17} color="#7c9b8c" />
            </div>

            <div className="activity-row">
              <i className="activity-dot" />
              <div>
                <b>Clinic Operations</b>
                <small>
                  Manage your daily clinic activities in one place.
                </small>
              </div>
            </div>

            <div className="activity-row">
              <i className="activity-dot" />
              <div>
                <b>Patient Care</b>
                <small>
                  Keep patient records and appointments organized.
                </small>
              </div>
            </div>

            <div className="activity-row">
              <i className="activity-dot" />
              <div>
                <b>Hospital Services</b>
                <small>
                  Access OPD, IPD, pharmacy and laboratory services.
                </small>
              </div>
            </div>
          </section>
        </div>
      </div>
    </>
  );
}
