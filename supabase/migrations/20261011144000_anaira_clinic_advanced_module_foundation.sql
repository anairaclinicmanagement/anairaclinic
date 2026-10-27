-- Additive foundations for advanced department queues and platform operations.
-- The live Anaira Clinic project already has these tables; IF NOT EXISTS keeps this safe there.
create table if not exists public.platform_audit_logs (
 id uuid primary key default gen_random_uuid(), actor_user_id uuid references auth.users(id) on delete set null,
 action text not null, entity_type text not null, entity_id text, details jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now()
);
create table if not exists public.platform_feature_flags (
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null, description text,
 enabled boolean not null default false, rollout_percent smallint not null default 100 check(rollout_percent between 0 and 100),
 updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now()
);
create table if not exists public.platform_settings (
 key text primary key, value jsonb not null default '{}'::jsonb,
 updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now()
);
create table if not exists public.platform_backup_runs (
 id uuid primary key default gen_random_uuid(), provider text not null default 'external', backup_type text not null default 'database',
 status text not null default 'queued' check(status in ('queued','running','completed','failed','verified')),
 started_at timestamptz, finished_at timestamptz, size_bytes bigint, artifact_reference text, error_summary text,
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.clinic_support_tickets (
 id uuid primary key default gen_random_uuid(), clinic_id uuid references public.clinics(id) on delete cascade,
 requester_id uuid not null references auth.users(id) on delete restrict, assigned_to uuid references auth.users(id) on delete set null,
 subject text not null check(length(trim(subject)) between 3 and 180),
 category text not null default 'general' check(category in ('general','billing','technical','security','clinical_workflow','data_request','integration')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 status text not null default 'open' check(status in ('open','in_progress','waiting_on_customer','resolved','closed')),
 description text not null check(length(trim(description)) between 3 and 10000), resolution text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), resolved_at timestamptz
);
create index if not exists clinic_support_tickets_clinic_created_idx on public.clinic_support_tickets(clinic_id,created_at desc);
create table if not exists public.hospital_work_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid references public.patients(id) on delete set null,
 module_key text not null check(module_key in ('radiology','operation_theatre','emergency','blood_bank','cssd','diet_nutrition','ambulance','procurement','assets','support','documents','telemedicine','referrals','clinical_quality','insurance','hr_payroll','patient_portal')),
 title text not null check(length(trim(title)) between 2 and 240),
 status text not null default 'open' check(status in ('open','scheduled','in_progress','pending_review','approved','collected','processing','verified','completed','cancelled','rejected','dispatched','resolved','closed','reserved','issued')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')), due_at timestamptz,
 details jsonb not null default '{}'::jsonb, created_by uuid references auth.users(id) on delete set null,
 updated_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists hospital_work_items_clinic_module_status_idx on public.hospital_work_items(clinic_id,module_key,status,created_at desc);
create index if not exists hospital_work_items_patient_idx on public.hospital_work_items(clinic_id,patient_id) where patient_id is not null;

alter table public.platform_audit_logs enable row level security;
alter table public.platform_feature_flags enable row level security;
alter table public.platform_settings enable row level security;
alter table public.platform_backup_runs enable row level security;
alter table public.clinic_support_tickets enable row level security;
alter table public.hospital_work_items enable row level security;

drop policy if exists platform_audit_logs_admin_read on public.platform_audit_logs;
create policy platform_audit_logs_admin_read on public.platform_audit_logs for select to authenticated using (private.is_platform_admin());
drop policy if exists platform_audit_logs_admin_insert on public.platform_audit_logs;
create policy platform_audit_logs_admin_insert on public.platform_audit_logs for insert to authenticated with check (private.is_platform_admin());
drop policy if exists feature_flags_admin_all on public.platform_feature_flags;
create policy feature_flags_admin_all on public.platform_feature_flags for all to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists feature_flags_read_enabled on public.platform_feature_flags;
create policy feature_flags_read_enabled on public.platform_feature_flags for select to authenticated using (enabled or private.is_platform_admin());
drop policy if exists platform_settings_admin_all on public.platform_settings;
create policy platform_settings_admin_all on public.platform_settings for all to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists platform_backups_admin_all on public.platform_backup_runs;
create policy platform_backups_admin_all on public.platform_backup_runs for all to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists support_ticket_select on public.clinic_support_tickets;
create policy support_ticket_select on public.clinic_support_tickets for select to authenticated using (private.is_platform_admin() or (clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'])));
drop policy if exists support_ticket_insert on public.clinic_support_tickets;
create policy support_ticket_insert on public.clinic_support_tickets for insert to authenticated with check (requester_id=(select auth.uid()) and clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']));
drop policy if exists support_ticket_clinic_admin_update on public.clinic_support_tickets;
create policy support_ticket_clinic_admin_update on public.clinic_support_tickets for update to authenticated using (clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin'])) with check (clinic_id is not null and private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists support_ticket_platform_update on public.clinic_support_tickets;
create policy support_ticket_platform_update on public.clinic_support_tickets for update to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists hospital_work_items_select_member on public.hospital_work_items;
create policy hospital_work_items_select_member on public.hospital_work_items for select to authenticated using (private.is_clinic_member(clinic_id));
drop policy if exists hospital_work_items_insert_member on public.hospital_work_items;
create policy hospital_work_items_insert_member on public.hospital_work_items for insert to authenticated with check (created_by=(select auth.uid()) and private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']));
drop policy if exists hospital_work_items_update_member on public.hospital_work_items;
create policy hospital_work_items_update_member on public.hospital_work_items for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']));
drop policy if exists hospital_work_items_delete_admin on public.hospital_work_items;
create policy hospital_work_items_delete_admin on public.hospital_work_items for delete to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']));

grant select,insert,update,delete on public.hospital_work_items to authenticated;
grant select,insert,update on public.clinic_support_tickets to authenticated;
grant select,insert,update on public.platform_feature_flags,public.platform_settings,public.platform_backup_runs,public.platform_audit_logs to authenticated;

insert into public.platform_feature_flags(code,name,description,enabled,rollout_percent) values
 ('radiology','Radiology / RIS','Imaging order workflow foundation',false,100),
 ('operation_theatre','Operation Theatre','Surgery scheduling and theatre workflow foundation',false,100),
 ('emergency','Emergency / Casualty','Emergency visit workflow foundation',false,100),
 ('blood_bank','Blood Bank','Blood component inventory and issue workflow foundation',false,100),
 ('cssd','CSSD / Sterilisation','Sterilisation cycle workflow foundation',false,100),
 ('diet','Diet & Nutrition','Inpatient diet workflow foundation',false,100),
 ('ambulance','Ambulance','Ambulance trip workflow foundation',false,100),
 ('procurement','Procurement','Purchase and receiving workflow foundation',false,100),
 ('asset_management','Assets & Maintenance','Equipment maintenance workflow foundation',false,100),
 ('telemedicine','Telemedicine','Remote consultation workflow foundation',false,100),
 ('referrals','Referrals','Referral tracking workflow foundation',false,100),
 ('clinical_quality','Clinical Quality','Quality event workflow foundation',false,100),
 ('patient_portal','Patient Portal','Patient self-service foundation',false,100),
 ('offline_sync','Offline Sync','Background sync capability gate',false,100)
on conflict(code) do nothing;
