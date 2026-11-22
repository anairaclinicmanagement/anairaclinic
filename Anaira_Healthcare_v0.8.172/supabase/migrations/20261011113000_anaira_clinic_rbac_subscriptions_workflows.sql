-- Anaira Clinic v0.2: tenant RBAC hardening + platform subscription foundations.
-- Does not modify any other Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;
drop policy if exists platform_admins_self_read on public.platform_admins;
create policy platform_admins_self_read on public.platform_admins for select to authenticated using (user_id = (select auth.uid()));
-- No authenticated INSERT/UPDATE/DELETE policy by design: bootstrap platform admins through trusted SQL/service role only.

create table if not exists public.clinic_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  price_monthly numeric(12,2) not null default 0 check(price_monthly >= 0),
  price_yearly numeric(12,2) not null default 0 check(price_yearly >= 0),
  max_branches integer not null default 1 check(max_branches > 0),
  max_staff integer not null default 5 check(max_staff > 0),
  enabled_modules text[] not null default array['patients','appointments','consultation','billing']::text[],
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.clinic_subscriptions (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  plan_id uuid references public.clinic_plans(id),
  status text not null default 'trial' check(status in ('trial','active','past_due','suspended','cancelled','expired')),
  billing_cycle text not null default 'monthly' check(billing_cycle in ('monthly','yearly')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  trial_ends_at timestamptz,
  provider text,
  provider_subscription_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(clinic_id)
);
create table if not exists public.clinic_module_overrides (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  module_code text not null,
  enabled boolean not null default true,
  expires_at timestamptz,
  changed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(clinic_id,module_code)
);
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id), expense_date date not null default current_date,
  category text not null, description text, amount numeric(12,2) not null check(amount >= 0),
  payment_method text not null default 'cash', reference_no text, created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  batch_id uuid references public.inventory_batches(id), movement_type text not null check(movement_type in ('opening','purchase','dispense','return','adjustment','expired','transfer_in','transfer_out')),
  quantity numeric(12,3) not null check(quantity > 0), reference_type text, reference_id uuid,
  notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.procedures (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id), patient_id uuid not null references public.patients(id),
  encounter_id uuid references public.encounters(id), procedure_name text not null, procedure_code text,
  scheduled_at timestamptz, status text not null default 'planned' check(status in ('planned','in_progress','completed','cancelled')),
  notes text, performed_by uuid references public.staff_profiles(id), created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.nursing_records (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id), admission_id uuid references public.admissions(id),
  patient_id uuid not null references public.patients(id), recorded_at timestamptz not null default now(),
  record_type text not null default 'note', observations jsonb not null default '{}'::jsonb,
  notes text, recorded_by uuid references public.staff_profiles(id), created_at timestamptz not null default now()
);
create table if not exists public.offline_mutations (
  id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
  client_mutation_id text not null, entity_table text not null, entity_id uuid, operation text not null check(operation in ('insert','update','delete')),
  payload jsonb not null default '{}'::jsonb, status text not null default 'pending' check(status in ('pending','processing','synced','conflict','failed')),
  attempts integer not null default 0, last_error text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), processed_at timestamptz,
  unique(clinic_id,client_mutation_id)
);

insert into public.clinic_plans(code,name,price_monthly,price_yearly,max_branches,max_staff,enabled_modules)
values
 ('starter','Starter',999,9990,1,5,array['patients','appointments','consultation','prescriptions','billing']::text[]),
 ('professional','Professional',2499,24990,5,25,array['patients','appointments','consultation','prescriptions','pharmacy','laboratory','billing','staff','reports']::text[]),
 ('hospital','Hospital',7999,79990,50,250,array['patients','appointments','consultation','prescriptions','pharmacy','laboratory','billing','staff','reports','ipd','insurance','multi_branch']::text[])
on conflict(code) do nothing;

create index if not exists clinic_subscriptions_status_idx on public.clinic_subscriptions(status,ends_at);
create index if not exists expenses_clinic_date_idx on public.expenses(clinic_id,expense_date desc);
create index if not exists stock_movements_clinic_batch_idx on public.stock_movements(clinic_id,batch_id,created_at desc);
create index if not exists procedures_clinic_patient_idx on public.procedures(clinic_id,patient_id,created_at desc);
create index if not exists nursing_records_clinic_patient_idx on public.nursing_records(clinic_id,patient_id,recorded_at desc);
create index if not exists offline_mutations_pending_idx on public.offline_mutations(clinic_id,status,created_at) where status in ('pending','processing','conflict','failed');

-- Role-aware permission helper. Caller can only check roles of the signed-in user.
create or replace function private.has_clinic_role(p_clinic_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.clinic_members cm where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true and cm.role=any(p_roles)); $$;
revoke all on function private.has_clinic_role(uuid,text[]) from public,anon;
grant execute on function private.has_clinic_role(uuid,text[]) to authenticated;

-- Remove broad member CRUD policies from clinic-scoped tables and replace with role-scoped rules.
do $$
declare t text; select_roles text[]; write_roles text[]; delete_roles text[];
begin
  foreach t in array array['clinic_branches','staff_profiles','doctor_schedules','patients','appointments','encounters','vitals','diagnoses','medications','prescriptions','prescription_items','inventory_batches','lab_tests','lab_orders','lab_order_items','services','invoices','invoice_items','payments','insurance_claims','rooms','admissions','clinic_settings','audit_logs','sync_outbox','expenses','stock_movements','procedures','nursing_records','offline_mutations'] loop
    execute format('drop policy if exists %I on public.%I',t||'_select_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_insert_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_update_member',t);
    execute format('drop policy if exists %I on public.%I',t||'_delete_member',t);
    select_roles := array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff'];
    write_roles := array['owner','admin'];
    delete_roles := array['owner','admin'];
    if t in ('patients','appointments') then write_roles := array['owner','admin','doctor','receptionist']; end if;
    if t in ('encounters','vitals','diagnoses','prescriptions','prescription_items','procedures') then write_roles := array['owner','admin','doctor']; end if;
    if t in ('nursing_records','admissions','rooms') then write_roles := array['owner','admin','doctor','nurse']; end if;
    if t in ('medications','inventory_batches','stock_movements') then write_roles := array['owner','admin','pharmacist']; end if;
    if t in ('lab_tests','lab_orders','lab_order_items') then write_roles := array['owner','admin','doctor','lab_technician']; end if;
    if t in ('invoices','invoice_items','payments','expenses','insurance_claims','services') then write_roles := array['owner','admin','accountant','receptionist']; end if;
    if t in ('clinic_branches','staff_profiles','doctor_schedules','clinic_settings') then write_roles := array['owner','admin']; end if;
    if t in ('audit_logs','sync_outbox','offline_mutations') then write_roles := array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']; end if;
    execute format('create policy %I on public.%I for select to authenticated using(private.has_clinic_role(clinic_id,%L::text[]))',t||'_select_role',t,select_roles);
    execute format('create policy %I on public.%I for insert to authenticated with check(private.has_clinic_role(clinic_id,%L::text[]))',t||'_insert_role',t,write_roles);
    execute format('create policy %I on public.%I for update to authenticated using(private.has_clinic_role(clinic_id,%L::text[])) with check(private.has_clinic_role(clinic_id,%L::text[]))',t||'_update_role',t,write_roles,write_roles);
    execute format('create policy %I on public.%I for delete to authenticated using(private.has_clinic_role(clinic_id,%L::text[]))',t||'_delete_role',t,delete_roles);
  end loop;
end $$;

-- Subscription and module controls are visible to clinic admins; platform administrators are managed out-of-band.
alter table public.clinic_plans enable row level security;
alter table public.clinic_subscriptions enable row level security;
alter table public.clinic_module_overrides enable row level security;
alter table public.expenses enable row level security;
alter table public.stock_movements enable row level security;
alter table public.procedures enable row level security;
alter table public.nursing_records enable row level security;
alter table public.offline_mutations enable row level security;
drop policy if exists clinic_plans_read_active on public.clinic_plans;
create policy clinic_plans_read_active on public.clinic_plans for select to authenticated using(active=true);
drop policy if exists clinic_subscriptions_select_admin on public.clinic_subscriptions;
create policy clinic_subscriptions_select_admin on public.clinic_subscriptions for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_module_overrides_select_admin on public.clinic_module_overrides;
create policy clinic_module_overrides_select_admin on public.clinic_module_overrides for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin']));

-- Avoid direct client privilege escalation through role-membership writes.
drop policy if exists clinic_members_insert_owner on public.clinic_members;
drop policy if exists clinic_members_update_owner on public.clinic_members;
drop policy if exists clinic_members_delete_owner on public.clinic_members;
create policy clinic_members_insert_admin on public.clinic_members for insert to authenticated with check(private.has_clinic_role(clinic_id,array['owner','admin']));
create policy clinic_members_update_admin on public.clinic_members for update to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin'])) with check(private.has_clinic_role(clinic_id,array['owner','admin']));
create policy clinic_members_delete_admin on public.clinic_members for delete to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin']) and user_id <> (select auth.uid()));

comment on table public.platform_admins is 'Platform-admin identities; provisioning must happen through trusted SQL/service-role operations only.';
comment on table public.offline_mutations is 'Idempotent offline mutation inbox; server-side replay processor is required before production sync.';
