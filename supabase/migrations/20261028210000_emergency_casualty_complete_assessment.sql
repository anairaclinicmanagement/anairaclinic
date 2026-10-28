-- Emergency / Casualty clinical documentation fields. Additive migration; existing visits are preserved.
alter table public.emergency_visits
  add column if not exists assigned_doctor_id uuid,
  add column if not exists bp_systolic integer,
  add column if not exists bp_diastolic integer,
  add column if not exists pulse_bpm integer,
  add column if not exists respiratory_rate integer,
  add column if not exists spo2_percent numeric(5,2),
  add column if not exists temperature_c numeric(4,1),
  add column if not exists blood_glucose numeric(8,2),
  add column if not exists gcs_score integer,
  add column if not exists pain_score integer,
  add column if not exists allergies text,
  add column if not exists medical_history text,
  add column if not exists injury_mechanism text,
  add column if not exists assessment_notes text,
  add column if not exists treatment_notes text,
  add column if not exists referral_hospital text,
  add column if not exists contact_person text,
  add column if not exists contact_phone text;

-- Keep constraints limited to clinical data bounds; blank values remain nullable.
alter table public.emergency_visits drop constraint if exists emergency_visits_vitals_bounds_check;
alter table public.emergency_visits add constraint emergency_visits_vitals_bounds_check check (
  (bp_systolic is null or bp_systolic between 0 and 300) and
  (bp_diastolic is null or bp_diastolic between 0 and 200) and
  (pulse_bpm is null or pulse_bpm between 0 and 300) and
  (respiratory_rate is null or respiratory_rate between 0 and 100) and
  (spo2_percent is null or spo2_percent between 0 and 100) and
  (temperature_c is null or temperature_c between 25 and 45) and
  (blood_glucose is null or blood_glucose between 0 and 2000) and
  (gcs_score is null or gcs_score between 3 and 15) and
  (pain_score is null or pain_score between 0 and 10)
);
create index if not exists emergency_visits_clinic_triage_arrival_idx
  on public.emergency_visits(clinic_id, triage_level, arrived_at desc);
grant select, insert, update on public.emergency_visits to authenticated;
