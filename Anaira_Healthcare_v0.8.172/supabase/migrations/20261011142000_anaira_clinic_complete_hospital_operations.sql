-- Anaira Clinic v0.6.0: multi-hospital advanced operations foundation
-- Additive migration only. All tenant data is scoped by clinic_id and protected by RLS.
create table if not exists public.hospital_work_items (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  patient_id uuid references public.patients(id) on delete set null,
  module_key text not null check (module_key in (
    'radiology','operation_theatre','emergency','blood_bank','cssd','diet_nutrition',
    'ambulance','procurement','assets','support','documents','telemedicine','referrals',
    'clinical_quality','insurance','hr_payroll','patient_portal'
  )),
  title text not null check (length(trim(title)) between 2 and 240),
  status text not null default 'open' check (status in (
    'open','scheduled','in_progress','pending_review','approved','collected','processing',
    'verified','completed','cancelled','rejected','dispatched','resolved','closed','reserved','issued'
  )),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  due_at timestamptz,
  details jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists hospital_work_items_tenant_module_idx on public.hospital_work_items(clinic_id,module_key,created_at desc);
create index if not exists hospital_work_items_tenant_status_idx on public.hospital_work_items(clinic_id,status,due_at);
alter table public.hospital_work_items enable row level security;
drop policy if exists hospital_work_items_select_member on public.hospital_work_items;
create policy hospital_work_items_select_member on public.hospital_work_items for select to authenticated using (private.is_clinic_member(clinic_id));
drop policy if exists hospital_work_items_insert_member on public.hospital_work_items;
create policy hospital_work_items_insert_member on public.hospital_work_items for insert to authenticated with check (
  created_by = (select auth.uid()) and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'])
);
drop policy if exists hospital_work_items_update_member on public.hospital_work_items;
create policy hospital_work_items_update_member on public.hospital_work_items for update to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']))
with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']));
drop policy if exists hospital_work_items_delete_admin on public.hospital_work_items;
create policy hospital_work_items_delete_admin on public.hospital_work_items for delete to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));

create table if not exists public.clinic_documents (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  patient_id uuid references public.patients(id) on delete set null,
  category text not null check (category in ('consent','medical_record','lab_report','radiology','prescription','discharge_summary','insurance','identity','other')),
  file_name text not null,
  storage_path text not null,
  content_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  sensitivity text not null default 'clinical' check (sensitivity in ('general','clinical','restricted')),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists clinic_documents_tenant_patient_idx on public.clinic_documents(clinic_id,patient_id,created_at desc);
alter table public.clinic_documents enable row level security;
drop policy if exists clinic_documents_select_member on public.clinic_documents;
create policy clinic_documents_select_member on public.clinic_documents for select to authenticated using (private.is_clinic_member(clinic_id));
drop policy if exists clinic_documents_insert_member on public.clinic_documents;
create policy clinic_documents_insert_member on public.clinic_documents for insert to authenticated with check (
  uploaded_by = (select auth.uid()) and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','lab_technician','accountant','staff'])
);
drop policy if exists clinic_documents_delete_admin on public.clinic_documents;
create policy clinic_documents_delete_admin on public.clinic_documents for delete to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));

create table if not exists public.clinical_quality_checks (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  patient_id uuid references public.patients(id) on delete set null,
  encounter_id uuid references public.encounters(id) on delete set null,
  check_type text not null,
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','assigned','in_review','resolved','accepted_risk')),
  description text not null,
  resolution text,
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.clinical_quality_checks enable row level security;
drop policy if exists clinical_quality_checks_select_member on public.clinical_quality_checks;
create policy clinical_quality_checks_select_member on public.clinical_quality_checks for select to authenticated using (private.is_clinic_member(clinic_id));
drop policy if exists clinical_quality_checks_write_admin_clinical on public.clinical_quality_checks;
create policy clinical_quality_checks_write_admin_clinical on public.clinical_quality_checks for all to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse']))
with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse']));

create table if not exists public.clinic_support_tickets (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  ticket_no text not null,
  subject text not null,
  description text not null,
  category text not null default 'general' check (category in ('general','billing','technical','clinical_workflow','security','data_request')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','waiting_user','resolved','closed')),
  created_by uuid references auth.users(id) on delete set null,
  assigned_to uuid references auth.users(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(clinic_id,ticket_no)
);
alter table public.clinic_support_tickets enable row level security;
drop policy if exists clinic_support_tickets_select_member on public.clinic_support_tickets;
create policy clinic_support_tickets_select_member on public.clinic_support_tickets for select to authenticated using (private.is_clinic_member(clinic_id));
drop policy if exists clinic_support_tickets_insert_member on public.clinic_support_tickets;
create policy clinic_support_tickets_insert_member on public.clinic_support_tickets for insert to authenticated with check (requester_id=(select auth.uid()) and private.is_clinic_member(clinic_id));
drop policy if exists clinic_support_tickets_update_admin on public.clinic_support_tickets;
create policy clinic_support_tickets_update_admin on public.clinic_support_tickets for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin'])) with check (private.has_clinic_role(clinic_id,array['owner','admin']));

create table if not exists public.clinic_integration_configs (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  provider text not null,
  integration_type text not null check (integration_type in ('payment','sms','email','whatsapp','lab','radiology','health_exchange','other')),
  enabled boolean not null default false,
  public_settings jsonb not null default '{}'::jsonb,
  secret_reference text,
  last_tested_at timestamptz,
  last_test_status text check (last_test_status is null or last_test_status in ('passed','failed','not_configured')),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(clinic_id,provider,integration_type)
);
alter table public.clinic_integration_configs enable row level security;
drop policy if exists clinic_integration_configs_select_admin on public.clinic_integration_configs;
create policy clinic_integration_configs_select_admin on public.clinic_integration_configs for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_integration_configs_write_admin on public.clinic_integration_configs;
create policy clinic_integration_configs_write_admin on public.clinic_integration_configs for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin'])) with check (private.has_clinic_role(clinic_id,array['owner','admin']));

create table if not exists public.clinic_sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  operation_id text not null,
  entity_table text not null,
  entity_id text not null,
  local_payload jsonb not null,
  server_payload jsonb,
  conflict_reason text not null,
  status text not null default 'open' check (status in ('open','resolved_local','resolved_server','merged','discarded')),
  resolved_by uuid references auth.users(id) on delete set null,
  resolution_notes text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
alter table public.clinic_sync_conflicts enable row level security;
drop policy if exists clinic_sync_conflicts_select_admin on public.clinic_sync_conflicts;
create policy clinic_sync_conflicts_select_admin on public.clinic_sync_conflicts for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_sync_conflicts_write_admin on public.clinic_sync_conflicts;
create policy clinic_sync_conflicts_write_admin on public.clinic_sync_conflicts for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin'])) with check (private.has_clinic_role(clinic_id,array['owner','admin']));

create table if not exists public.clinic_backup_runs (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  backup_type text not null check (backup_type in ('scheduled','manual','pre_migration','restore_test')),
  status text not null default 'queued' check (status in ('queued','running','completed','failed','verified')),
  storage_reference text,
  started_at timestamptz,
  completed_at timestamptz,
  verified_at timestamptz,
  bytes_stored bigint,
  checksum text,
  error_summary text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.clinic_backup_runs enable row level security;
drop policy if exists clinic_backup_runs_select_admin on public.clinic_backup_runs;
create policy clinic_backup_runs_select_admin on public.clinic_backup_runs for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_backup_runs_insert_admin on public.clinic_backup_runs;
create policy clinic_backup_runs_insert_admin on public.clinic_backup_runs for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin']) and created_by=(select auth.uid()));

-- Domain-specific operational tables: strict tenant key, lifecycle status and JSONB details
-- permit the first release to support configurable specialties while retaining structured identifiers.
create table if not exists public.radiology_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  encounter_id uuid references public.encounters(id) on delete set null, modality text not null, body_region text,
  priority text not null default 'normal' check(priority in ('normal','urgent','stat')), status text not null default 'ordered' check(status in ('ordered','scheduled','in_progress','reported','cancelled')),
  scheduled_at timestamptz, findings text, impression text, report_path text, ordered_by uuid references auth.users(id) on delete set null,
  reported_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.operation_theatre_cases (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  procedure_name text not null, surgeon_id uuid references public.staff_profiles(id) on delete set null, anaesthetist_id uuid references public.staff_profiles(id) on delete set null,
  scheduled_start timestamptz, scheduled_end timestamptz, status text not null default 'planned' check(status in ('planned','pre_op','in_progress','recovery','completed','cancelled')),
  pre_op_checklist jsonb not null default '{}'::jsonb, anaesthesia_notes text, operative_notes text, post_op_notes text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.emergency_visits (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  triage_level text not null check(triage_level in ('red','orange','yellow','green','blue')), arrival_mode text,
  chief_complaint text not null, triage_notes text, status text not null default 'triaged' check(status in ('triaged','under_assessment','stabilized','admitted','transferred','discharged','deceased')),
  arrived_at timestamptz not null default now(), disposition_notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.blood_inventory_components (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, unit_code text not null, blood_group text not null,
  component_type text not null, collected_at timestamptz, expires_at timestamptz, status text not null default 'available' check(status in ('available','reserved','issued','expired','discarded','quarantined')),
  donor_reference text, screening jsonb not null default '{}'::jsonb, issued_to_patient_id uuid references public.patients(id) on delete set null,
  issued_at timestamptz, created_at timestamptz not null default now(), unique(clinic_id,unit_code)
);
create table if not exists public.cssd_cycles (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, cycle_no text not null, sterilizer_id text,
  cycle_type text not null, started_at timestamptz, completed_at timestamptz, parameters jsonb not null default '{}'::jsonb,
  result text not null default 'pending' check(result in ('pending','passed','failed','quarantined')), load_description text,
  operator_id uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), unique(clinic_id,cycle_no)
);
create table if not exists public.diet_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
  admission_id uuid references public.admissions(id) on delete set null, diet_type text not null, restrictions text,
  calories_kcal integer, status text not null default 'active' check(status in ('active','paused','completed','cancelled')),
  starts_at timestamptz not null default now(), ends_at timestamptz, ordered_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.ambulance_trips (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, vehicle_code text not null, driver_name text,
  patient_id uuid references public.patients(id) on delete set null, pickup_address text not null, destination_address text,
  dispatch_at timestamptz, arrival_at timestamptz, return_at timestamptz, status text not null default 'requested' check(status in ('requested','dispatched','on_scene','transporting','completed','cancelled')),
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.procurement_orders (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, order_no text not null, supplier_name text not null,
  status text not null default 'draft' check(status in ('draft','submitted','approved','ordered','part_received','received','cancelled')),
  currency char(3) not null default 'INR', subtotal numeric(12,2) not null default 0, tax_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0, expected_at date, received_at timestamptz, line_items jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id) on delete set null, approved_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  unique(clinic_id,order_no), check(subtotal>=0 and tax_amount>=0 and total_amount>=0)
);
create table if not exists public.clinic_assets (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null, asset_code text not null, name text not null,
  category text not null, serial_number text, location text, purchase_date date, warranty_until date, calibration_due date,
  status text not null default 'active' check(status in ('active','maintenance','out_of_service','retired')),
  last_service_at date, next_service_at date, notes text, created_at timestamptz not null default now(), unique(clinic_id,asset_code)
);

-- Apply tenant isolation to all newly introduced operational tables.
do $$
declare t text;
begin
  foreach t in array array[
    'radiology_orders','operation_theatre_cases','emergency_visits','blood_inventory_components',
    'cssd_cycles','diet_orders','ambulance_trips','procurement_orders','clinic_assets'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_select_member',t);
    execute format('create policy %I on public.%I for select to authenticated using (private.is_clinic_member(clinic_id))',t||'_select_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_insert_member',t);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.has_clinic_role(clinic_id,array[''owner'',''admin'',''doctor'',''nurse'',''receptionist'',''lab_technician'',''pharmacist'',''accountant'',''staff'']))',t||'_insert_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_update_member',t);
    execute format('create policy %I on public.%I for update to authenticated using (private.has_clinic_role(clinic_id,array[''owner'',''admin'',''doctor'',''nurse'',''receptionist'',''lab_technician'',''pharmacist'',''accountant'',''staff''])) with check (private.has_clinic_role(clinic_id,array[''owner'',''admin'',''doctor'',''nurse'',''receptionist'',''lab_technician'',''pharmacist'',''accountant'',''staff'']))',t||'_update_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_delete_admin',t);
    execute format('create policy %I on public.%I for delete to authenticated using (private.has_clinic_role(clinic_id,array[''owner'',''admin'']))',t||'_delete_admin',t);
  end loop;
end $$;

create index if not exists radiology_orders_tenant_status_idx on public.radiology_orders(clinic_id,status,scheduled_at);
create index if not exists emergency_visits_tenant_status_idx on public.emergency_visits(clinic_id,status,arrived_at desc);
create index if not exists operation_theatre_cases_tenant_status_idx on public.operation_theatre_cases(clinic_id,status,scheduled_start);
create index if not exists blood_inventory_tenant_expiry_idx on public.blood_inventory_components(clinic_id,status,expires_at);
create index if not exists ambulance_trips_tenant_status_idx on public.ambulance_trips(clinic_id,status,dispatched_at desc);

create or replace function public.update_hospital_work_item_status(p_clinic_id uuid,p_item_id uuid,p_status text,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_item public.hospital_work_items%rowtype;
begin
 if not private.is_clinic_member(p_clinic_id) then raise exception 'Clinic membership required'; end if;
 if p_status not in ('open','scheduled','in_progress','pending_review','approved','collected','processing','verified','completed','cancelled','rejected','dispatched','resolved','closed','reserved','issued') then raise exception 'Invalid workflow status'; end if;
 update public.hospital_work_items set status=p_status, updated_by=auth.uid(), updated_at=now(),
   details=case when p_notes is null or btrim(p_notes)='' then details else details || jsonb_build_object('last_status_note',p_notes,'last_status_note_at',now()) end
 where id=p_item_id and clinic_id=p_clinic_id returning * into v_item;
 if not found then raise exception 'Work item not found in this clinic'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,auth.uid(),'hospital_work_item_status_changed',v_item.module_key,v_item.id::text,jsonb_build_object('status',p_status,'note',p_notes));
 return jsonb_build_object('id',v_item.id,'status',v_item.status,'updated_at',v_item.updated_at);
end $$;
revoke all on function public.update_hospital_work_item_status(uuid,uuid,text,text) from public,anon;
grant execute on function public.update_hospital_work_item_status(uuid,uuid,text,text) to authenticated;
