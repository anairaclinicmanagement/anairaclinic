-- Anaira Clinic Management System
-- Apply ONLY to a NEW, DEDICATED Supabase project. Never run on the Anaira CRM project.
begin;
create extension if not exists pgcrypto;

create type public.member_role as enum ('owner','clinic_admin','doctor','receptionist','nurse','lab_technician','pharmacist','accountant','patient');
create type public.appointment_status as enum ('scheduled','checked_in','waiting','in_consultation','completed','cancelled','no_show');
create type public.invoice_status as enum ('draft','issued','partially_paid','paid','void','refunded');
create type public.payment_method as enum ('cash','upi','card','bank_transfer','online','insurance','other');
create type public.lab_order_status as enum ('ordered','sample_collected','processing','result_ready','verified','cancelled');
create type public.sync_state as enum ('pending','processing','synced','error');

create table public.clinics (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 slug text unique,
 clinic_type text not null default 'general',
 phone text,
 email text,
 address text,
 city text,
 state text,
 postal_code text,
 country text not null default 'India',
 timezone text not null default 'Asia/Kolkata',
 currency text not null default 'INR',
 logo_path text,
 settings jsonb not null default '{}'::jsonb,
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.clinic_members (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.member_role not null default 'receptionist',
 display_name text,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 unique(clinic_id,user_id)
);
create index clinic_members_user_idx on public.clinic_members(user_id,clinic_id);

create or replace function public.is_clinic_member(target_clinic uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.clinic_members m where m.clinic_id=target_clinic and m.user_id=auth.uid() and m.active=true)
$$;
create or replace function public.has_clinic_role(target_clinic uuid, allowed public.member_role[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.clinic_members m where m.clinic_id=target_clinic and m.user_id=auth.uid() and m.active=true and m.role=any(allowed))
$$;
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path=public,pg_temp as $$ begin new.updated_at=now(); return new; end $$;
create or replace function public.generate_uhid()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.uhid is null or length(trim(new.uhid))=0 then
  new.uhid := 'AN-' || upper(substr(replace(new.clinic_id::text,'-',''),1,4)) || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 end if;
 return new;
end $$;

create table public.doctors (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 user_id uuid references auth.users(id) on delete set null, full_name text not null, specialty text, registration_number text,
 phone text, email text, consultation_fee numeric(12,2) not null default 0 check(consultation_fee>=0),
 schedule jsonb not null default '{}'::jsonb, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index doctors_clinic_idx on public.doctors(clinic_id,active);

create table public.patients (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 uhid text, full_name text not null, phone text, email text, date_of_birth date, age_years integer check(age_years is null or age_years between 0 and 125),
 gender text, blood_group text, photo_path text, address text, city text, state text, postal_code text,
 emergency_contact_name text, emergency_contact_phone text, guardian_name text, family_group_id uuid,
 allergies text[] not null default '{}', ongoing_medicines text, medical_history text, consent_status text not null default 'pending',
 notes text, created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), archived_at timestamptz,
 unique(clinic_id,uhid),
 unique(id,clinic_id)
);
create index patients_clinic_name_idx on public.patients(clinic_id,lower(full_name));
create index patients_clinic_phone_idx on public.patients(clinic_id,phone);
create trigger patients_generate_uhid before insert on public.patients for each row execute function public.generate_uhid();

create table public.appointments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null references public.patients(id) on delete restrict, doctor_id uuid references public.doctors(id) on delete set null,
 scheduled_at timestamptz not null, duration_minutes integer not null default 15 check(duration_minutes between 5 and 480),
 token_number integer, visit_type text not null default 'consultation', reason text, status public.appointment_status not null default 'scheduled',
 source text not null default 'reception', reminder_status text, created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint appointment_patient_clinic_fk foreign key(patient_id,clinic_id) references public.patients(id,clinic_id) deferrable initially deferred,
 unique(id,clinic_id)
);
-- Composite references require a matching unique key.
create unique index if not exists doctors_id_clinic_unique on public.doctors(id,clinic_id);
create index appointments_clinic_schedule_idx on public.appointments(clinic_id,scheduled_at,status);

create table public.encounters (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null, appointment_id uuid, doctor_id uuid references public.doctors(id) on delete set null,
 encounter_at timestamptz not null default now(), chief_complaint text, symptoms text, examination text, diagnosis text,
 blood_pressure text, pulse integer, temperature numeric(5,2), spo2 numeric(5,2), weight_kg numeric(6,2), height_cm numeric(6,2), bmi numeric(6,2),
 clinical_notes text, follow_up_date date, status text not null default 'draft', signed_at timestamptz, signed_by uuid references auth.users(id) on delete set null,
 created_by uuid default auth.uid() references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint encounter_patient_clinic_fk foreign key(patient_id,clinic_id) references public.patients(id,clinic_id),
 constraint encounter_appointment_clinic_fk foreign key(appointment_id,clinic_id) references public.appointments(id,clinic_id)
);
create index encounters_patient_date_idx on public.encounters(clinic_id,patient_id,encounter_at desc);

create table public.prescriptions (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null, encounter_id uuid references public.encounters(id) on delete set null, doctor_id uuid references public.doctors(id) on delete set null,
 prescription_number text, advice text, diagnosis text, follow_up_date date, status text not null default 'draft',
 signed_at timestamptz, signed_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
 constraint prescription_patient_clinic_fk foreign key(patient_id,clinic_id) references public.patients(id,clinic_id)
);
create table public.prescription_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 prescription_id uuid not null references public.prescriptions(id) on delete cascade, medicine_id uuid,
 medicine_name text not null, strength text, dose text, route text, frequency text, duration text, quantity numeric(12,2), instructions text, created_at timestamptz not null default now()
);

create table public.services (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 code text, name text not null, category text not null default 'consultation', description text, price numeric(12,2) not null default 0 check(price>=0), tax_rate numeric(5,2) not null default 0 check(tax_rate between 0 and 100), active boolean not null default true,
 created_at timestamptz not null default now(), unique(clinic_id,code)
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 patient_id uuid not null, appointment_id uuid, invoice_number text, subtotal numeric(12,2) not null default 0 check(subtotal>=0), discount_amount numeric(12,2) not null default 0 check(discount_amount>=0), tax_amount numeric(12,2) not null default 0 check(tax_amount>=0), total_amount numeric(12,2) not null default 0 check(total_amount>=0), paid_amount numeric(12,2) not null default 0 check(paid_amount>=0), status public.invoice_status not null default 'draft', notes text, issued_at timestamptz, due_at timestamptz, created_by uuid default auth.uid() references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint invoice_patient_clinic_fk foreign key(patient_id,clinic_id) references public.patients(id,clinic_id),
 constraint invoice_appointment_clinic_fk foreign key(appointment_id,clinic_id) references public.appointments(id,clinic_id),
 unique(id,clinic_id)
);
create unique index invoices_clinic_number_unique on public.invoices(clinic_id,invoice_number) where invoice_number is not null;
create table public.invoice_items (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, invoice_id uuid not null,
 service_id uuid references public.services(id) on delete set null, description text not null, quantity numeric(12,2) not null default 1 check(quantity>0), unit_price numeric(12,2) not null default 0 check(unit_price>=0), tax_rate numeric(5,2) not null default 0, line_total numeric(12,2) not null default 0, created_at timestamptz not null default now(),
 constraint invoice_item_invoice_clinic_fk foreign key(invoice_id,clinic_id) references public.invoices(id,clinic_id)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, invoice_id uuid not null,
 amount numeric(12,2) not null check(amount>0), method public.payment_method not null default 'cash', reference_number text, status text not null default 'received', received_at timestamptz not null default now(), received_by uuid default auth.uid() references auth.users(id) on delete set null, notes text,
 constraint payment_invoice_clinic_fk foreign key(invoice_id,clinic_id) references public.invoices(id,clinic_id)
);

create table public.medicines (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, name text not null, generic_name text, brand text, strength text, dosage_form text, unit text default 'unit', manufacturer text, reorder_level numeric(12,2) not null default 0, active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index medicines_clinic_name_idx on public.medicines(clinic_id,lower(name));
create table public.suppliers (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, name text not null, phone text, email text, address text, tax_number text, created_at timestamptz not null default now()
);
create table public.inventory_batches (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, medicine_id uuid not null references public.medicines(id) on delete restrict, supplier_id uuid references public.suppliers(id) on delete set null,
 batch_number text not null, expiry_date date, purchase_price numeric(12,2) not null default 0, selling_price numeric(12,2) not null default 0, quantity_received numeric(12,2) not null default 0, quantity_available numeric(12,2) not null default 0, received_at timestamptz not null default now(), created_at timestamptz not null default now(), unique(clinic_id,medicine_id,batch_number)
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, medicine_id uuid not null references public.medicines(id) on delete restrict, batch_id uuid references public.inventory_batches(id) on delete set null,
 movement_type text not null check(movement_type in ('purchase','dispense','return','adjustment','expired','transfer_in','transfer_out')), quantity_delta numeric(12,2) not null, reference_type text, reference_id uuid, notes text, created_by uuid default auth.uid() references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

create table public.lab_tests (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, code text, name text not null, category text, specimen_type text, instructions text, price numeric(12,2) not null default 0, reference_range text, unit text, active boolean not null default true, created_at timestamptz not null default now(), unique(clinic_id,code)
);
create table public.lab_orders (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, patient_id uuid not null, test_id uuid not null references public.lab_tests(id) on delete restrict, encounter_id uuid references public.encounters(id) on delete set null,
 order_number text, status public.lab_order_status not null default 'ordered', ordered_by uuid default auth.uid() references auth.users(id) on delete set null, ordered_at timestamptz not null default now(), sample_collected_at timestamptz, result_ready_at timestamptz, verified_at timestamptz, verified_by uuid references auth.users(id) on delete set null, notes text,
 constraint lab_order_patient_clinic_fk foreign key(patient_id,clinic_id) references public.patients(id,clinic_id)
);
create table public.lab_results (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, lab_order_id uuid not null references public.lab_orders(id) on delete cascade, analyte text not null, result_value text, unit text, reference_range text, abnormal_flag text, notes text, entered_by uuid default auth.uid() references auth.users(id) on delete set null, entered_at timestamptz not null default now()
);

create table public.clinic_branches (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, name text not null, code text, phone text, address text, timezone text not null default 'Asia/Kolkata', active boolean not null default true, created_at timestamptz not null default now(), unique(clinic_id,code)
);
create table public.staff_profiles (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, user_id uuid references auth.users(id) on delete set null, full_name text not null, role_title text, phone text, email text, employment_status text not null default 'active', joined_on date, created_at timestamptz not null default now()
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, actor_user_id uuid references auth.users(id) on delete set null, action text not null, entity_type text not null, entity_id uuid, metadata jsonb not null default '{}'::jsonb, ip_address inet, created_at timestamptz not null default now()
);
create index audit_logs_clinic_date_idx on public.audit_logs(clinic_id,created_at desc);
create table public.sync_events (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade, user_id uuid references auth.users(id) on delete set null, client_operation_id text not null, entity_type text not null, operation text not null check(operation in ('insert','update','delete')), payload jsonb not null default '{}'::jsonb, state public.sync_state not null default 'pending', attempts integer not null default 0, last_error text, created_at timestamptz not null default now(), processed_at timestamptz, unique(clinic_id,user_id,client_operation_id)
);

-- updated_at triggers
create trigger clinics_touch before update on public.clinics for each row execute function public.touch_updated_at();
create trigger doctors_touch before update on public.doctors for each row execute function public.touch_updated_at();
create trigger patients_touch before update on public.patients for each row execute function public.touch_updated_at();
create trigger appointments_touch before update on public.appointments for each row execute function public.touch_updated_at();
create trigger encounters_touch before update on public.encounters for each row execute function public.touch_updated_at();
create trigger invoices_touch before update on public.invoices for each row execute function public.touch_updated_at();
create trigger medicines_touch before update on public.medicines for each row execute function public.touch_updated_at();

-- RLS: all clinical data is isolated by clinic membership.
alter table public.clinics enable row level security;
alter table public.clinic_members enable row level security;
create policy clinics_select_member on public.clinics for select to authenticated using (public.is_clinic_member(id) or created_by=auth.uid());
create policy clinics_insert_owner on public.clinics for insert to authenticated with check (created_by=auth.uid());
create policy clinics_update_admin on public.clinics for update to authenticated using (public.has_clinic_role(id,array['owner','clinic_admin']::public.member_role[])) with check (public.has_clinic_role(id,array['owner','clinic_admin']::public.member_role[]));
create policy members_select_same_clinic on public.clinic_members for select to authenticated using (public.is_clinic_member(clinic_id) or user_id=auth.uid());
create policy members_insert_bootstrap_or_admin on public.clinic_members for insert to authenticated with check (
 (user_id=auth.uid() and exists(select 1 from public.clinics c where c.id=clinic_id and c.created_by=auth.uid() and role='owner'))
 or public.has_clinic_role(clinic_id,array['owner','clinic_admin']::public.member_role[])
);
create policy members_update_admin on public.clinic_members for update to authenticated using (public.has_clinic_role(clinic_id,array['owner','clinic_admin']::public.member_role[])) with check (public.has_clinic_role(clinic_id,array['owner','clinic_admin']::public.member_role[]));
create policy members_delete_admin on public.clinic_members for delete to authenticated using (public.has_clinic_role(clinic_id,array['owner','clinic_admin']::public.member_role[]));

do $$
declare t text;
begin
 foreach t in array array['doctors','patients','appointments','encounters','prescriptions','prescription_items','services','invoices','invoice_items','payments','medicines','suppliers','inventory_batches','stock_movements','lab_tests','lab_orders','lab_results','clinic_branches','staff_profiles','audit_logs','sync_events'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I on public.%I for select to authenticated using (public.is_clinic_member(clinic_id))',t||'_select_member',t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.has_clinic_role(clinic_id,array[''owner'',''clinic_admin'',''doctor'',''receptionist'',''nurse'',''lab_technician'',''pharmacist'',''accountant'']::public.member_role[]))',t||'_insert_staff',t);
  execute format('create policy %I on public.%I for update to authenticated using (public.has_clinic_role(clinic_id,array[''owner'',''clinic_admin'',''doctor'',''receptionist'',''nurse'',''lab_technician'',''pharmacist'',''accountant'']::public.member_role[])) with check (public.has_clinic_role(clinic_id,array[''owner'',''clinic_admin'',''doctor'',''receptionist'',''nurse'',''lab_technician'',''pharmacist'',''accountant'']::public.member_role[]))',t||'_update_staff',t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.has_clinic_role(clinic_id,array[''owner'',''clinic_admin'']::public.member_role[]))',t||'_delete_admin',t);
 end loop;
end $$;

-- This migration intentionally does not create a clinic or a login user.
-- Sign up the first administrator, then follow README bootstrap SQL.
commit;
