-- Anaira Clinic core schema. Applied to Supabase project gdyvzvzmybbvufggxjty.
-- Includes tenant/clinic isolation, clinical operations, billing, inventory and offline sync queue.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.clinics (
 id uuid primary key default gen_random_uuid(), name text not null,
 clinic_type text not null default 'general_opd' check (clinic_type in ('general_opd','dental','eye','skin','pediatrics','gynecology','orthopedic','ayurveda','homeopathy','physiotherapy','diagnostic_lab','polyclinic','hospital','other')),
 registration_number text, phone text, email text, address jsonb not null default '{}'::jsonb,
 timezone text not null default 'Asia/Kolkata', currency char(3) not null default 'INR',
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.clinic_members (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff')),
 display_name text, active boolean not null default true, created_at timestamptz not null default now(),
 unique (clinic_id,user_id)
);
create index clinic_members_user_idx on public.clinic_members(user_id,active);
create table public.clinic_branches (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 name text not null, code text, phone text, address jsonb not null default '{}'::jsonb,
 is_primary boolean not null default false, active boolean not null default true, created_at timestamptz not null default now(),
 unique(clinic_id,code)
);
create table public.staff_profiles (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, user_id uuid references auth.users(id) on delete set null,
 staff_code text, full_name text not null, role text not null default 'staff', phone text, email text, specialty text,
 registration_number text, active boolean not null default true, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), unique(clinic_id,staff_code)
);
create table public.doctor_schedules (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, doctor_id uuid not null references public.staff_profiles(id) on delete cascade,
 weekday smallint not null check(weekday between 0 and 6), start_time time not null, end_time time not null,
 slot_minutes smallint not null default 15 check(slot_minutes between 5 and 240), effective_from date, effective_to date,
 active boolean not null default true, check(end_time > start_time)
);
create table public.patients (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, uhid text not null, first_name text not null,
 middle_name text, last_name text, date_of_birth date, gender text check(gender in ('female','male','other','unknown')),
 blood_group text, phone text, alternate_phone text, email text, address jsonb not null default '{}'::jsonb,
 emergency_contact jsonb not null default '{}'::jsonb, allergies text[] not null default '{}', medical_alerts text,
 consent jsonb not null default '{}'::jsonb, notes text, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), archived_at timestamptz,
 unique(clinic_id,uhid)
);
create index patients_clinic_name_idx on public.patients(clinic_id,lower(first_name),lower(coalesce(last_name,'')));
create index patients_clinic_phone_idx on public.patients(clinic_id,phone);
create table public.appointments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
 doctor_id uuid references public.staff_profiles(id) on delete set null, appointment_no text, appointment_at timestamptz not null,
 duration_minutes smallint not null default 15 check(duration_minutes between 5 and 480),
 visit_type text not null default 'opd' check(visit_type in ('opd','follow_up','procedure','teleconsultation','emergency')),
 status text not null default 'booked' check(status in ('booked','checked_in','in_consultation','completed','cancelled','no_show')),
 reason text, queue_number integer, source text not null default 'reception',
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index appointments_clinic_time_idx on public.appointments(clinic_id,appointment_at,status);
create index appointments_patient_idx on public.appointments(clinic_id,patient_id,appointment_at desc);
create table public.encounters (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
 appointment_id uuid references public.appointments(id) on delete set null, doctor_id uuid references public.staff_profiles(id) on delete set null,
 encounter_no text, encounter_type text not null default 'opd' check(encounter_type in ('opd','ipd','emergency','teleconsultation','procedure')),
 chief_complaint text, history_of_present_illness text, examination text, assessment text, plan text, notes text,
 status text not null default 'open' check(status in ('open','signed','closed','amended')),
 started_at timestamptz not null default now(), closed_at timestamptz, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index encounters_patient_idx on public.encounters(clinic_id,patient_id,started_at desc);
create table public.vitals (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 encounter_id uuid not null references public.encounters(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete restrict,
 recorded_by uuid references auth.users(id) on delete set null, height_cm numeric(6,2), weight_kg numeric(6,2),
 temperature_c numeric(4,1), pulse_bpm integer, respiratory_rate integer, systolic_bp integer, diastolic_bp integer,
 spo2 numeric(5,2), blood_glucose numeric(7,2), pain_score smallint check(pain_score between 0 and 10),
 notes text, recorded_at timestamptz not null default now()
);
create table public.diagnoses (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 encounter_id uuid not null references public.encounters(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete restrict,
 code_system text, code text, label text not null, is_primary boolean not null default false, notes text, created_at timestamptz not null default now()
);
create table public.medications (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 name text not null, generic_name text, strength text, dosage_form text, manufacturer text, sku text, barcode text,
 reorder_level numeric(12,3) not null default 0, active boolean not null default true, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), unique(clinic_id,sku)
);
create table public.prescriptions (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 encounter_id uuid not null references public.encounters(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete restrict,
 doctor_id uuid references public.staff_profiles(id) on delete set null, prescription_no text, instructions text,
 status text not null default 'draft' check(status in ('draft','signed','dispensed','cancelled')),
 prescribed_at timestamptz not null default now(), created_at timestamptz not null default now()
);
create table public.prescription_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 prescription_id uuid not null references public.prescriptions(id) on delete cascade, medication_id uuid references public.medications(id) on delete set null,
 medicine_name text not null, dose text, route text, frequency text, duration_days integer check(duration_days is null or duration_days>0),
 quantity numeric(12,3), timing_instructions text, notes text
);
create table public.inventory_batches (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 medication_id uuid not null references public.medications(id) on delete cascade, batch_number text not null, expiry_date date,
 quantity_on_hand numeric(12,3) not null default 0 check(quantity_on_hand>=0), purchase_rate numeric(12,2) not null default 0,
 sale_rate numeric(12,2) not null default 0, supplier_name text, received_at timestamptz not null default now(),
 created_at timestamptz not null default now(), unique(clinic_id,medication_id,batch_number)
);
create index inventory_expiry_idx on public.inventory_batches(clinic_id,expiry_date);
create table public.lab_tests (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 test_code text, name text not null, specimen text, price numeric(12,2) not null default 0 check(price>=0), unit text,
 reference_range text, active boolean not null default true, created_at timestamptz not null default now(), unique(clinic_id,test_code)
);
create table public.lab_orders (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null references public.patients(id) on delete restrict, encounter_id uuid references public.encounters(id) on delete set null,
 ordered_by uuid references public.staff_profiles(id) on delete set null, order_no text,
 status text not null default 'ordered' check(status in ('ordered','collected','processing','completed','cancelled')),
 ordered_at timestamptz not null default now(), collected_at timestamptz, completed_at timestamptz, notes text, created_at timestamptz not null default now()
);
create table public.lab_order_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 lab_order_id uuid not null references public.lab_orders(id) on delete cascade, lab_test_id uuid references public.lab_tests(id) on delete set null,
 test_name text not null, status text not null default 'pending' check(status in ('pending','processing','completed','cancelled')),
 result_text text, result_numeric numeric(14,4), result_unit text, reference_range text,
 abnormal_flag text check(abnormal_flag in ('low','normal','high','critical','unknown')),
 reported_by uuid references auth.users(id) on delete set null, reported_at timestamptz, notes text
);
create table public.services (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, code text, name text not null,
 category text not null default 'consultation', price numeric(12,2) not null default 0 check(price>=0),
 tax_percent numeric(5,2) not null default 0 check(tax_percent between 0 and 100), active boolean not null default true,
 created_at timestamptz not null default now(), unique(clinic_id,code)
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
 encounter_id uuid references public.encounters(id) on delete set null, invoice_no text not null,
 status text not null default 'draft' check(status in ('draft','issued','part_paid','paid','void','refunded')),
 subtotal numeric(12,2) not null default 0, discount_amount numeric(12,2) not null default 0, tax_amount numeric(12,2) not null default 0,
 total_amount numeric(12,2) not null default 0, paid_amount numeric(12,2) not null default 0, due_at timestamptz, issued_at timestamptz,
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(clinic_id,invoice_no), check(subtotal>=0 and discount_amount>=0 and tax_amount>=0 and total_amount>=0 and paid_amount>=0)
);
create table public.invoice_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 invoice_id uuid not null references public.invoices(id) on delete cascade, service_id uuid references public.services(id) on delete set null,
 item_type text not null default 'service', description text not null, quantity numeric(12,3) not null default 1 check(quantity>0),
 unit_price numeric(12,2) not null default 0 check(unit_price>=0), discount_amount numeric(12,2) not null default 0 check(discount_amount>=0),
 tax_percent numeric(5,2) not null default 0 check(tax_percent between 0 and 100), line_total numeric(12,2) not null default 0
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 invoice_id uuid not null references public.invoices(id) on delete restrict, patient_id uuid not null references public.patients(id) on delete restrict,
 amount numeric(12,2) not null check(amount>0), method text not null check(method in ('cash','card','upi','bank_transfer','insurance','other')),
 transaction_reference text, status text not null default 'completed' check(status in ('pending','completed','failed','refunded')),
 received_by uuid references auth.users(id) on delete set null, paid_at timestamptz not null default now(), notes text
);
create table public.insurance_claims (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null references public.patients(id) on delete restrict, invoice_id uuid references public.invoices(id) on delete set null,
 payer_name text not null, policy_number text, claim_number text, claimed_amount numeric(12,2) not null default 0, approved_amount numeric(12,2),
 status text not null default 'draft' check(status in ('draft','submitted','under_review','approved','rejected','settled')),
 submitted_at timestamptz, settled_at timestamptz, notes text, created_at timestamptz not null default now()
);
create table public.rooms (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, room_number text not null, ward_name text,
 room_type text not null default 'general', bed_count integer not null default 1 check(bed_count>0), active boolean not null default true,
 unique(clinic_id,branch_id,room_number)
);
create table public.admissions (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 branch_id uuid references public.clinic_branches(id) on delete set null, patient_id uuid not null references public.patients(id) on delete restrict,
 room_id uuid references public.rooms(id) on delete set null, encounter_id uuid references public.encounters(id) on delete set null,
 admission_no text not null, admitted_at timestamptz not null default now(), discharged_at timestamptz,
 status text not null default 'admitted' check(status in ('admitted','transferred','discharged','cancelled','deceased')),
 admitting_doctor_id uuid references public.staff_profiles(id) on delete set null, discharge_summary text, notes text,
 created_at timestamptz not null default now(), unique(clinic_id,admission_no)
);
create table public.clinic_settings (
 clinic_id uuid primary key references public.clinics(id) on delete cascade, settings jsonb not null default '{}'::jsonb,
 updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now()
);
create table public.audit_logs (
 id bigint generated always as identity primary key, clinic_id uuid not null references public.clinics(id) on delete cascade,
 actor_user_id uuid references auth.users(id) on delete set null, action text not null, entity_type text not null,
 entity_id text, details jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now()
);
create index audit_logs_clinic_time_idx on public.audit_logs(clinic_id,occurred_at desc);
create table public.sync_outbox (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 device_id text not null, client_mutation_id text not null, entity_type text not null, entity_id text,
 operation text not null check(operation in ('insert','update','delete')), payload jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check(status in ('pending','processing','synced','failed','conflict')),
 attempt_count integer not null default 0, last_error text, created_at timestamptz not null default now(), processed_at timestamptz,
 unique(clinic_id,device_id,client_mutation_id)
);
create index sync_outbox_pending_idx on public.sync_outbox(clinic_id,status,created_at);

create or replace function private.is_clinic_member(p_clinic_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.clinic_members cm where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true); $$;
create or replace function private.has_clinic_role(p_clinic_id uuid,p_roles text[]) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.clinic_members cm where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true and cm.role=any(p_roles)); $$;
revoke all on function private.is_clinic_member(uuid) from public,anon;
revoke all on function private.has_clinic_role(uuid,text[]) from public,anon;
grant execute on function private.is_clinic_member(uuid) to authenticated;
grant execute on function private.has_clinic_role(uuid,text[]) to authenticated;

create or replace function public.create_clinic_with_owner(p_name text,p_clinic_type text default 'general_opd') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_user_id uuid:=auth.uid(); v_clinic_id uuid;
begin
 if v_user_id is null then raise exception 'Authentication required'; end if;
 if coalesce(trim(p_name),'')='' then raise exception 'Clinic name is required'; end if;
 if p_clinic_type not in ('general_opd','dental','eye','skin','pediatrics','gynecology','orthopedic','ayurveda','homeopathy','physiotherapy','diagnostic_lab','polyclinic','hospital','other') then raise exception 'Unsupported clinic type'; end if;
 insert into public.clinics(name,clinic_type,created_by) values(trim(p_name),p_clinic_type,v_user_id) returning id into v_clinic_id;
 insert into public.clinic_members(clinic_id,user_id,role) values(v_clinic_id,v_user_id,'owner');
 insert into public.clinic_settings(clinic_id) values(v_clinic_id);
 return v_clinic_id;
end; $$;
revoke all on function public.create_clinic_with_owner(text,text) from public,anon;
grant execute on function public.create_clinic_with_owner(text,text) to authenticated;

alter table public.clinics enable row level security;
alter table public.clinic_members enable row level security;
alter table public.clinic_branches enable row level security;
alter table public.staff_profiles enable row level security;
alter table public.doctor_schedules enable row level security;
alter table public.patients enable row level security;
alter table public.appointments enable row level security;
alter table public.encounters enable row level security;
alter table public.vitals enable row level security;
alter table public.diagnoses enable row level security;
alter table public.medications enable row level security;
alter table public.prescriptions enable row level security;
alter table public.prescription_items enable row level security;
alter table public.inventory_batches enable row level security;
alter table public.lab_tests enable row level security;
alter table public.lab_orders enable row level security;
alter table public.lab_order_items enable row level security;
alter table public.services enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.payments enable row level security;
alter table public.insurance_claims enable row level security;
alter table public.rooms enable row level security;
alter table public.admissions enable row level security;
alter table public.clinic_settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.sync_outbox enable row level security;

create policy clinics_select_member on public.clinics for select to authenticated using(private.is_clinic_member(id));
create policy clinics_insert_creator on public.clinics for insert to authenticated with check(created_by=(select auth.uid()));
create policy clinics_update_owner on public.clinics for update to authenticated using(private.has_clinic_role(id,array['owner','admin'])) with check(private.has_clinic_role(id,array['owner','admin']));
create policy clinic_members_select_self_or_admin on public.clinic_members for select to authenticated using(user_id=(select auth.uid()) or private.has_clinic_role(clinic_id,array['owner','admin']));
create policy clinic_settings_select_member on public.clinic_settings for select to authenticated using(private.is_clinic_member(clinic_id));
create policy clinic_settings_insert_admin on public.clinic_settings for insert to authenticated with check(private.has_clinic_role(clinic_id,array['owner','admin']));
create policy clinic_settings_update_admin on public.clinic_settings for update to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin'])) with check(private.has_clinic_role(clinic_id,array['owner','admin']));
do $$ declare t text; begin
 foreach t in array array['clinic_branches','staff_profiles','doctor_schedules','patients','appointments','encounters','vitals','diagnoses','medications','prescriptions','prescription_items','inventory_batches','lab_tests','lab_orders','lab_order_items','services','invoices','invoice_items','payments','insurance_claims','rooms','admissions','audit_logs','sync_outbox'] loop
 execute format('create policy %I on public.%I for select to authenticated using(private.is_clinic_member(clinic_id))',t||'_select_member',t);
 execute format('create policy %I on public.%I for insert to authenticated with check(private.is_clinic_member(clinic_id))',t||'_insert_member',t);
 execute format('create policy %I on public.%I for update to authenticated using(private.is_clinic_member(clinic_id)) with check(private.is_clinic_member(clinic_id))',t||'_update_member',t);
 execute format('create policy %I on public.%I for delete to authenticated using(private.is_clinic_member(clinic_id))',t||'_delete_member',t);
 end loop;
end $$;
revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on all sequences in schema public to authenticated;
