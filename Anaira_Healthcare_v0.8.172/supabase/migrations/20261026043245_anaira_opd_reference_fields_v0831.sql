-- Anaira Clinic v0.8.31: OPD reference-screen fields
-- Idempotent: safe to apply once through Supabase migration tooling.
alter table public.opd_visits
  add column if not exists referred_by text,
  add column if not exists visit_type text not null default 'New';

alter table public.opd_visits
  drop constraint if exists opd_visits_visit_type_check;

alter table public.opd_visits
  add constraint opd_visits_visit_type_check
  check (visit_type in ('New', 'Follow-up', 'Emergency'));

create index if not exists opd_visits_clinic_visit_type_issued_idx
  on public.opd_visits (clinic_id, visit_type, issued_at desc);

comment on column public.opd_visits.referred_by is
  'Referral source captured at OPD reception; free text to support clinic-specific referral sources.';
comment on column public.opd_visits.visit_type is
  'OPD visit category: New, Follow-up, or Emergency.';
