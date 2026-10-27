-- Compatibility repair for Emergency/Casualty schema variants across existing deployments.
-- Additive/constraint-only: preserves patient and visit records.
alter table public.emergency_visits
  add column if not exists arrival_mode text,
  add column if not exists triage_notes text,
  add column if not exists disposition_notes text,
  add column if not exists updated_at timestamptz not null default now();

-- The application uses modern triage labels while earlier deployments used clinical urgency labels.
-- Accept both vocabularies so existing rows remain valid and the current form can save.
alter table public.emergency_visits drop constraint if exists emergency_visits_triage_level_check;
alter table public.emergency_visits add constraint emergency_visits_triage_level_check
  check (triage_level in ('red','orange','yellow','green','blue','resuscitation','emergency','urgent','semi_urgent','non_urgent'));

-- Preserve legacy status values while allowing the current Emergency workflow states.
alter table public.emergency_visits drop constraint if exists emergency_visits_status_check;
alter table public.emergency_visits add constraint emergency_visits_status_check
  check (status in ('triaged','being_seen','observation','admitted','discharged','transferred','left_without_being_seen','under_assessment','stabilized','deceased'));

-- Existing policies remain in force. Grant only the table privileges the client workflow needs.
grant select, insert, update on public.emergency_visits to authenticated;
create index if not exists emergency_visits_clinic_arrival_mode_idx
  on public.emergency_visits(clinic_id, arrival_mode, arrived_at desc);
