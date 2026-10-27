-- Anaira Clinic v0.6.0: multi-clinic SaaS control plane and hospital department foundations.
-- Additive migration only. Does not drop or rewrite existing clinical records.
create extension if not exists pgcrypto with schema extensions;

-- Platform control plane
create table if not exists public.platform_audit_logs (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists platform_audit_logs_time_idx on public.platform_audit_logs(occurred_at desc);

create table if not exists public.platform_feature_flags (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null,
  description text,
  enabled boolean not null default false,
  rollout_percent smallint not null default 100 check(rollout_percent between 0 and 100),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_settings (
  key text primary key check (key ~ '^[a-z][a-z0-9_.-]{1,100}$'),
  value jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_usage_events (
  id bigint generated always as identity primary key,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  metric_code text not null,
  quantity numeric(14,3) not null default 1 check(quantity >= 0),
  period_start date not null default date_trunc('month', now())::date,
  metadata jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);
create index if not exists platform_usage_events_clinic_period_idx on public.platform_usage_events(clinic_id,period_start desc,metric_code);

create table if not exists public.platform_backup_runs (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'external',
  backup_type text not null default 'database' check(backup_type in ('database','storage','full')),
  status text not null default 'queued' check(status in ('queued','running','succeeded','failed','verified')),
  started_at timestamptz,
  finished_at timestamptz,
  size_bytes bigint check(size_bytes is null or size_bytes >= 0),
  artifact_reference text,
  error_summary text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.clinic_support_tickets (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid references public.clinics(id) on delete set null,
  requester_id uuid not null references auth.users(id) on delete restrict,
  assigned_to uuid references auth.users(id) on delete set null,
  subject text not null check(length(trim(subject)) between 3 and 180),
  category text not null default 'general' check(category in ('general','billing','technical','security','clinical_workflow','data_request','integration')),
  priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
  status text not null default 'open' check(status in ('open','in_progress','waiting_on_customer','resolved','closed')),
  description text not null check(length(trim(description)) between 3 and 10000),
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists clinic_support_tickets_status_idx on public.clinic_support_tickets(status,priority,created_at desc);
create index if not exists clinic_support_tickets_clinic_idx on public.clinic_support_tickets(clinic_id,created_at desc);

-- Patient consent and document metadata. Actual files belong in a private Storage bucket.
create table if not exists public.patient_consents (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  consent_type text not null,
  policy_version text not null,
  status text not null default 'granted' check(status in ('granted','denied','revoked','expired')),
  captured_by uuid references auth.users(id) on delete set null,
  captured_at timestamptz not null default now(),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists patient_consents_patient_idx on public.patient_consents(clinic_id,patient_id,captured_at desc);

create table if not exists public.patient_documents (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  document_type text not null,
  file_name text not null,
  mime_type text,
  byte_size bigint check(byte_size is null or byte_size >= 0),
  storage_bucket text not null default 'patient-documents',
  storage_path text not null,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(clinic_id,storage_bucket,storage_path)
);
create index if not exists patient_documents_patient_idx on public.patient_documents(clinic_id,patient_id,created_at desc);

-- Advanced hospital departments: structured tenant-owned records, not unscoped JSON blobs.
create table if not exists public.radiology_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  encounter_id uuid references public.encounters(id) on delete set null, order_no text, modality text not null,
  body_site text, priority text not null default 'routine' check(priority in ('routine','urgent','stat')),
  status text not null default 'ordered' check(status in ('ordered','scheduled','in_progress','reported','cancelled')),
  scheduled_at timestamptz, findings text, impression text, report_storage_path text,
  ordered_by uuid references auth.users(id) on delete set null, reported_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.operation_theatre_cases (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  encounter_id uuid references public.encounters(id) on delete set null, procedure_name text not null,
  surgeon_id uuid references public.staff_profiles(id) on delete set null, anaesthesia_type text,
  scheduled_start timestamptz, scheduled_end timestamptz,
  status text not null default 'planned' check(status in ('planned','pre_op','in_progress','recovery','completed','cancelled')),
  pre_op_checklist jsonb not null default '{}'::jsonb, operative_notes text, post_op_notes text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(scheduled_end is null or scheduled_start is null or scheduled_end > scheduled_start)
);

create table if not exists public.emergency_visits (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  triage_level text not null default 'urgent' check(triage_level in ('resuscitation','emergency','urgent','semi_urgent','non_urgent')),
  chief_complaint text not null, arrived_at timestamptz not null default now(), status text not null default 'triaged' check(status in ('triaged','being_seen','observation','admitted','discharged','transferred','left_without_being_seen')),
  initial_assessment text, vitals jsonb not null default '{}'::jsonb, disposition text, clinician_id uuid references public.staff_profiles(id) on delete set null,
  closed_at timestamptz, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table if not exists public.blood_donors (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  donor_code text, full_name text not null, phone text, blood_group text not null check(blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown')),
  date_of_birth date, last_donation_date date, eligibility_status text not null default 'pending' check(eligibility_status in ('pending','eligible','deferred','ineligible')),
  deferral_until date, notes text, active boolean not null default true, created_at timestamptz not null default now(), unique(clinic_id,donor_code)
);

create table if not exists public.blood_components (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  unit_code text not null, component_type text not null check(component_type in ('whole_blood','red_cells','platelets','plasma','cryoprecipitate')),
  blood_group text not null check(blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  donor_id uuid references public.blood_donors(id) on delete set null, collected_at timestamptz not null,
  expires_at timestamptz not null, status text not null default 'available' check(status in ('available','reserved','issued','discarded','quarantined')),
  screening jsonb not null default '{}'::jsonb, storage_location text, created_at timestamptz not null default now(), unique(clinic_id,unit_code), check(expires_at > collected_at)
);

create table if not exists public.blood_issues (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  component_id uuid not null references public.blood_components(id) on delete restrict, patient_id uuid not null references public.patients(id) on delete restrict,
  crossmatch_status text not null default 'pending' check(crossmatch_status in ('pending','compatible','incompatible','not_required')),
  issued_at timestamptz, issued_by uuid references auth.users(id) on delete set null, return_status text not null default 'not_returned' check(return_status in ('not_returned','returned','transfused','discarded')),
  notes text, created_at timestamptz not null default now()
);

create table if not exists public.sterilization_cycles (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, cycle_no text not null, equipment_name text not null,
  load_description text, started_at timestamptz not null default now(), completed_at timestamptz,
  result text not null default 'pending' check(result in ('pending','passed','failed')), indicators jsonb not null default '{}'::jsonb,
  operator_id uuid references public.staff_profiles(id) on delete set null, notes text, created_at timestamptz not null default now(), unique(clinic_id,cycle_no)
);

create table if not exists public.diet_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  admission_id uuid references public.admissions(id) on delete set null, diet_type text not null,
  instructions text, allergy_notes text, start_at timestamptz not null default now(), end_at timestamptz,
  status text not null default 'active' check(status in ('active','completed','cancelled')), ordered_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.ambulance_trips (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null, vehicle_code text not null, driver_name text, crew jsonb not null default '[]'::jsonb,
  pickup_location text not null, dropoff_location text, dispatched_at timestamptz, arrived_at timestamptz, completed_at timestamptz,
  status text not null default 'requested' check(status in ('requested','dispatched','on_scene','transporting','completed','cancelled')),
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, po_number text not null, vendor_name text not null,
  order_date date not null default current_date, expected_delivery date, status text not null default 'draft' check(status in ('draft','submitted','approved','partially_received','received','cancelled')),
  subtotal numeric(14,2) not null default 0 check(subtotal >= 0), tax_amount numeric(14,2) not null default 0 check(tax_amount >= 0), total_amount numeric(14,2) not null default 0 check(total_amount >= 0),
  approved_by uuid references auth.users(id) on delete set null, received_at timestamptz, notes text, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(clinic_id,po_number)
);
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade, item_code text, description text not null,
  quantity numeric(14,3) not null check(quantity > 0), unit_cost numeric(14,2) not null check(unit_cost >= 0), received_quantity numeric(14,3) not null default 0 check(received_quantity >= 0),
  tax_percent numeric(5,2) not null default 0 check(tax_percent between 0 and 100), created_at timestamptz not null default now()
);

create table if not exists public.clinic_assets (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, asset_tag text not null, name text not null, category text not null,
  serial_number text, location text, purchase_date date, purchase_cost numeric(14,2) check(purchase_cost is null or purchase_cost >= 0),
  warranty_end date, status text not null default 'active' check(status in ('active','maintenance','retired','lost')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(clinic_id,asset_tag)
);
create table if not exists public.maintenance_work_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  asset_id uuid references public.clinic_assets(id) on delete set null, title text not null, description text,
  priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
  status text not null default 'open' check(status in ('open','assigned','in_progress','waiting_parts','completed','cancelled')),
  assigned_to uuid references public.staff_profiles(id) on delete set null, opened_at timestamptz not null default now(), due_at timestamptz, closed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table if not exists public.teleconsultations (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete restrict, appointment_id uuid references public.appointments(id) on delete set null,
  provider text, provider_reference text, join_url text, status text not null default 'scheduled' check(status in ('scheduled','waiting','in_progress','completed','cancelled','failed')),
  starts_at timestamptz, ends_at timestamptz, consent_id uuid references public.patient_consents(id) on delete set null,
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete restrict, encounter_id uuid references public.encounters(id) on delete set null,
  referred_to text not null, specialty text, reason text not null, urgency text not null default 'routine' check(urgency in ('routine','urgent','emergency')),
  status text not null default 'created' check(status in ('created','sent','accepted','completed','cancelled')),
  referred_at timestamptz not null default now(), closed_at timestamptz, external_reference text, notes text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table if not exists public.clinical_quality_events (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null, event_type text not null,
  severity text not null default 'moderate' check(severity in ('low','moderate','high','critical')),
  description text not null, status text not null default 'reported' check(status in ('reported','under_review','action_required','resolved','closed')),
  action_taken text, reported_by uuid references auth.users(id) on delete set null, reviewed_by uuid references auth.users(id) on delete set null,
  reported_at timestamptz not null default now(), resolved_at timestamptz, created_at timestamptz not null default now()
);

create table if not exists public.patient_feedback (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null, rating smallint not null check(rating between 1 and 5),
  category text not null default 'general', comments text, status text not null default 'new' check(status in ('new','reviewing','responded','closed')),
  response text, received_at timestamptz not null default now(), responded_by uuid references auth.users(id) on delete set null, responded_at timestamptz
);

create table if not exists public.staff_shifts (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, staff_profile_id uuid not null references public.staff_profiles(id) on delete cascade,
  starts_at timestamptz not null, ends_at timestamptz not null, status text not null default 'scheduled' check(status in ('scheduled','confirmed','completed','cancelled','absent')),
  shift_type text not null default 'regular', notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), check(ends_at > starts_at)
);
create table if not exists public.staff_leave_requests (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  staff_profile_id uuid not null references public.staff_profiles(id) on delete cascade, leave_type text not null,
  starts_on date not null, ends_on date not null, reason text, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
  reviewed_by uuid references auth.users(id) on delete set null, reviewed_at timestamptz, created_at timestamptz not null default now(), check(ends_on >= starts_on)
);

-- Row-level security: all tenant data is scoped by clinic_id and explicit role lists.
do $$
declare t text; v_read text[]; v_write text[]; v_delete text[];
begin
  foreach t in array array[
    'patient_consents','patient_documents','radiology_orders','operation_theatre_cases','emergency_visits',
    'blood_donors','blood_components','blood_issues','sterilization_cycles','diet_orders','ambulance_trips',
    'purchase_orders','purchase_order_items','clinic_assets','maintenance_work_orders','teleconsultations',
    'referrals','clinical_quality_events','patient_feedback','staff_shifts','staff_leave_requests'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_tenant_select',t);
    execute format('drop policy if exists %I on public.%I',t||'_tenant_insert',t);
    execute format('drop policy if exists %I on public.%I',t||'_tenant_update',t);
    execute format('drop policy if exists %I on public.%I',t||'_tenant_delete',t);
    v_read := array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'];
    v_write := array['owner','admin'];
    v_delete := array['owner','admin'];
    if t in ('patient_consents','patient_documents','radiology_orders','teleconsultations','referrals') then v_write := array['owner','admin','doctor','receptionist']; end if;
    if t in ('emergency_visits','operation_theatre_cases','diet_orders','nursing_records') then v_write := array['owner','admin','doctor','nurse']; end if;
    if t in ('blood_donors','blood_components','blood_issues','sterilization_cycles') then v_write := array['owner','admin','doctor','nurse','staff']; end if;
    if t in ('purchase_orders','purchase_order_items','clinic_assets','maintenance_work_orders') then v_write := array['owner','admin','accountant','staff']; end if;
    if t in ('patient_feedback','clinical_quality_events') then v_write := array['owner','admin','doctor','nurse','receptionist','staff']; end if;
    if t in ('staff_shifts','staff_leave_requests') then v_write := array['owner','admin','staff']; end if;
    execute format('create policy %I on public.%I for select to authenticated using(private.has_clinic_role(clinic_id,%L::text[]))',t||'_tenant_select',t,v_read);
    execute format('create policy %I on public.%I for insert to authenticated with check(private.has_clinic_role(clinic_id,%L::text[]))',t||'_tenant_insert',t,v_write);
    execute format('create policy %I on public.%I for update to authenticated using(private.has_clinic_role(clinic_id,%L::text[])) with check(private.has_clinic_role(clinic_id,%L::text[]))',t||'_tenant_update',t,v_write,v_write);
    execute format('create policy %I on public.%I for delete to authenticated using(private.has_clinic_role(clinic_id,%L::text[]))',t||'_tenant_delete',t,v_delete);
  end loop;
end $$;

alter table public.platform_audit_logs enable row level security;
alter table public.platform_feature_flags enable row level security;
alter table public.platform_settings enable row level security;
alter table public.platform_usage_events enable row level security;
alter table public.platform_backup_runs enable row level security;
alter table public.clinic_support_tickets enable row level security;

drop policy if exists platform_audit_admin_all on public.platform_audit_logs;
create policy platform_audit_admin_all on public.platform_audit_logs for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists feature_flags_read_enabled on public.platform_feature_flags;
create policy feature_flags_read_enabled on public.platform_feature_flags for select to authenticated using(enabled or private.is_platform_admin());
drop policy if exists feature_flags_admin_all on public.platform_feature_flags;
create policy feature_flags_admin_all on public.platform_feature_flags for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists platform_settings_admin_all on public.platform_settings;
create policy platform_settings_admin_all on public.platform_settings for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists platform_usage_admin_select on public.platform_usage_events;
create policy platform_usage_admin_select on public.platform_usage_events for select to authenticated using(private.is_platform_admin() or private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists platform_usage_admin_write on public.platform_usage_events;
create policy platform_usage_admin_write on public.platform_usage_events for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists platform_backups_admin_all on public.platform_backup_runs;
create policy platform_backups_admin_all on public.platform_backup_runs for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists support_ticket_select on public.clinic_support_tickets;
create policy support_ticket_select on public.clinic_support_tickets for select to authenticated using(private.is_platform_admin() or (clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'])));
drop policy if exists support_ticket_insert on public.clinic_support_tickets;
create policy support_ticket_insert on public.clinic_support_tickets for insert to authenticated with check(requester_id=(select auth.uid()) and clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']));
drop policy if exists support_ticket_platform_update on public.clinic_support_tickets;
create policy support_ticket_platform_update on public.clinic_support_tickets for update to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());
drop policy if exists support_ticket_clinic_admin_update on public.clinic_support_tickets;
create policy support_ticket_clinic_admin_update on public.clinic_support_tickets for update to authenticated using(clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin'])) with check(clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin']));

-- Allow platform admins to administer module overrides without exposing these writes to clinic users.
drop policy if exists clinic_module_overrides_platform_all on public.clinic_module_overrides;
create policy clinic_module_overrides_platform_all on public.clinic_module_overrides for all to authenticated using(private.is_platform_admin()) with check(private.is_platform_admin());

-- Clinic creation now provisions its primary branch and a trial subscription atomically.
create or replace function public.create_clinic_with_owner(p_name text,p_clinic_type text default 'general_opd') returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid:=auth.uid(); v_clinic_id uuid; v_plan_id uuid;
begin
 if v_user_id is null then raise exception 'Authentication required'; end if;
 if coalesce(trim(p_name),'')='' then raise exception 'Clinic name is required'; end if;
 if p_clinic_type not in ('general_opd','dental','eye','skin','pediatrics','gynecology','orthopedic','ayurveda','homeopathy','physiotherapy','diagnostic_lab','polyclinic','hospital','other') then raise exception 'Unsupported clinic type'; end if;
 insert into public.clinics(name,clinic_type,created_by) values(trim(p_name),p_clinic_type,v_user_id) returning id into v_clinic_id;
 insert into public.clinic_members(clinic_id,user_id,role) values(v_clinic_id,v_user_id,'owner');
 insert into public.clinic_settings(clinic_id,settings,updated_by) values(v_clinic_id,'{}'::jsonb,v_user_id);
 insert into public.clinic_branches(clinic_id,name,code,is_primary) values(v_clinic_id,'Main Branch','MAIN',true);
 select id into v_plan_id from public.clinic_plans where code='starter' and active=true limit 1;
 insert into public.clinic_subscriptions(clinic_id,plan_id,status,billing_cycle,starts_at,trial_ends_at,metadata) values(v_clinic_id,v_plan_id,'trial','monthly',now(),now()+interval '14 days',jsonb_build_object('source','self_signup'));
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(v_clinic_id,v_user_id,'create_clinic','clinic',v_clinic_id::text,jsonb_build_object('clinic_type',p_clinic_type));
 return v_clinic_id;
end $$;
revoke all on function public.create_clinic_with_owner(text,text) from public,anon;
grant execute on function public.create_clinic_with_owner(text,text) to authenticated;

create or replace function public.platform_admin_create_clinic(p_name text,p_clinic_type text,p_owner_email text,p_phone text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid; v_admin uuid:=auth.uid(); v_clinic uuid; v_plan uuid;
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if coalesce(trim(p_name),'')='' then raise exception 'Clinic name is required'; end if;
 if coalesce(trim(p_owner_email),'')='' then raise exception 'Owner email is required'; end if;
 select id into v_user from auth.users where lower(email)=lower(trim(p_owner_email)) limit 1;
 if v_user is null then raise exception 'No Supabase Auth user found for this owner email. Ask the owner to create an account first.'; end if;
 insert into public.clinics(name,clinic_type,email,phone,created_by,platform_status) values(trim(p_name),p_clinic_type,lower(trim(p_owner_email)),nullif(trim(coalesce(p_phone,'')),''),v_admin,'active') returning id into v_clinic;
 insert into public.clinic_members(clinic_id,user_id,role,display_name,active) values(v_clinic,v_user,'owner',trim(p_owner_email),true);
 insert into public.clinic_branches(clinic_id,name,code,is_primary) values(v_clinic,'Main Branch','MAIN',true);
 insert into public.clinic_settings(clinic_id,settings,updated_by) values(v_clinic,'{}'::jsonb,v_admin);
 select id into v_plan from public.clinic_plans where code='starter' and active=true limit 1;
 insert into public.clinic_subscriptions(clinic_id,plan_id,status,billing_cycle,starts_at,trial_ends_at,metadata) values(v_clinic,v_plan,'trial','monthly',now(),now()+interval '14 days',jsonb_build_object('source','platform_admin'));
 insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details) values(v_admin,'create_clinic','clinic',v_clinic::text,jsonb_build_object('name',trim(p_name),'owner_email',lower(trim(p_owner_email))));
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(v_clinic,v_admin,'platform_created_clinic','clinic',v_clinic::text,jsonb_build_object('owner_email',lower(trim(p_owner_email))));
 return jsonb_build_object('clinic_id',v_clinic,'owner_user_id',v_user,'status','active');
end $$;
revoke all on function public.platform_admin_create_clinic(text,text,text,text) from public,anon;
grant execute on function public.platform_admin_create_clinic(text,text,text,text) to authenticated;

create or replace function public.platform_admin_save_plan(p_plan_id uuid,p_code text,p_name text,p_price_monthly numeric,p_price_yearly numeric,p_max_branches integer,p_max_staff integer,p_enabled_modules text[],p_active boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_user uuid:=auth.uid();
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if coalesce(trim(p_code),'') !~ '^[a-z][a-z0-9_]{1,39}$' then raise exception 'Plan code must be lowercase letters, digits and underscores'; end if;
 if coalesce(trim(p_name),'')='' or p_price_monthly<0 or p_price_yearly<0 or p_max_branches<1 or p_max_staff<1 then raise exception 'Plan name, prices and limits are invalid'; end if;
 if coalesce(array_length(p_enabled_modules,1),0)=0 then raise exception 'At least one module must be enabled'; end if;
 if p_plan_id is null then
   insert into public.clinic_plans(code,name,price_monthly,price_yearly,max_branches,max_staff,enabled_modules,active) values(lower(trim(p_code)),trim(p_name),p_price_monthly,p_price_yearly,p_max_branches,p_max_staff,p_enabled_modules,p_active) returning id into v_id;
 else
   update public.clinic_plans set code=lower(trim(p_code)),name=trim(p_name),price_monthly=p_price_monthly,price_yearly=p_price_yearly,max_branches=p_max_branches,max_staff=p_max_staff,enabled_modules=p_enabled_modules,active=p_active where id=p_plan_id returning id into v_id;
   if v_id is null then raise exception 'Plan not found'; end if;
 end if;
 insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details) values(v_user,case when p_plan_id is null then 'create_plan' else 'update_plan' end,'clinic_plan',v_id::text,jsonb_build_object('code',p_code,'name',p_name,'monthly',p_price_monthly,'yearly',p_price_yearly,'max_branches',p_max_branches,'max_staff',p_max_staff,'modules',p_enabled_modules,'active',p_active));
 return jsonb_build_object('plan_id',v_id,'active',p_active);
end $$;
revoke all on function public.platform_admin_save_plan(uuid,text,text,numeric,numeric,integer,integer,text[],boolean) from public,anon;
grant execute on function public.platform_admin_save_plan(uuid,text,text,numeric,numeric,integer,integer,text[],boolean) to authenticated;

create or replace function public.platform_admin_set_module_override(p_clinic_id uuid,p_module_code text,p_enabled boolean,p_expires_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if coalesce(trim(p_module_code),'')='' then raise exception 'Module code is required'; end if;
 insert into public.clinic_module_overrides(clinic_id,module_code,enabled,expires_at,changed_by) values(p_clinic_id,lower(trim(p_module_code)),p_enabled,p_expires_at,v_user)
 on conflict(clinic_id,module_code) do update set enabled=excluded.enabled,expires_at=excluded.expires_at,changed_by=excluded.changed_by returning id into v_id;
 insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details) values(v_user,'set_module_override','clinic_module_override',v_id::text,jsonb_build_object('clinic_id',p_clinic_id,'module_code',p_module_code,'enabled',p_enabled,'expires_at',p_expires_at));
 return jsonb_build_object('id',v_id,'clinic_id',p_clinic_id,'module_code',p_module_code,'enabled',p_enabled);
end $$;
revoke all on function public.platform_admin_set_module_override(uuid,text,boolean,timestamptz) from public,anon;
grant execute on function public.platform_admin_set_module_override(uuid,text,boolean,timestamptz) to authenticated;

create or replace function public.clinic_module_access(p_clinic_id uuid,p_module_code text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_plan_modules text[]; v_override boolean; v_status text; v_sub_status text; v_end timestamptz;
begin
 if private.is_platform_admin() then return true; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']) then return false; end if;
 select c.platform_status,s.status,s.ends_at,p.enabled_modules into v_status,v_sub_status,v_end,v_plan_modules
 from public.clinics c left join public.clinic_subscriptions s on s.clinic_id=c.id left join public.clinic_plans p on p.id=s.plan_id where c.id=p_clinic_id;
 if v_status is distinct from 'active' then return false; end if;
 if v_sub_status not in ('trial','active') or (v_end is not null and v_end<now()) then return false; end if;
 select enabled into v_override from public.clinic_module_overrides where clinic_id=p_clinic_id and module_code=lower(p_module_code) and (expires_at is null or expires_at>now()) limit 1;
 if v_override is not null then return v_override; end if;
 return coalesce(lower(p_module_code)=any(v_plan_modules),false);
end $$;
revoke all on function public.clinic_module_access(uuid,text) from public,anon;
grant execute on function public.clinic_module_access(uuid,text) to authenticated;

-- Feature flag seed set. These are disabled until explicitly enabled by the platform owner.
insert into public.platform_feature_flags(code,name,description,enabled,rollout_percent) values
 ('radiology','Radiology / RIS','Imaging orders and report workflows',false,100),
 ('operation_theatre','Operation Theatre','Surgery scheduling and peri-operative documentation',false,100),
 ('emergency','Emergency / Casualty','Triage and emergency visit tracking',false,100),
 ('blood_bank','Blood Bank','Donor, component inventory and issue traceability',false,100),
 ('cssd','CSSD / Sterilisation','Sterilisation cycle and instrument load tracking',false,100),
 ('diet','Diet & Nutrition','Diet orders for inpatient care',false,100),
 ('ambulance','Ambulance','Dispatch and trip records',false,100),
 ('procurement','Procurement','Purchase orders and receiving',false,100),
 ('asset_management','Assets & Maintenance','Asset register and maintenance work orders',false,100),
 ('telemedicine','Telemedicine','Remote consultation scheduling and records',false,100),
 ('referrals','Referrals','Internal and external referral tracking',false,100),
 ('clinical_quality','Clinical Quality','Quality event and incident review',false,100),
 ('patient_portal','Patient Portal','Patient self-service access',false,100),
 ('offline_sync','Offline Sync','Conflict-safe background mutation replay',false,100)
on conflict(code) do nothing;

comment on table public.platform_backup_runs is 'Backup run metadata only; an external backup/restore orchestrator must perform and verify actual backups.';
comment on table public.patient_documents is 'Private Storage metadata only. Configure a private bucket and signed URL access; do not make patient files public.';
comment on table public.offline_mutations is 'Queue inbox only; a trusted idempotent replay processor is required before automatic production sync.';
