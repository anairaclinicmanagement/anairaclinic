-- IPD package catalogue and admission-level package assignment.
create table if not exists public.ipd_packages (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  name text not null,
  category text not null default 'General',
  description text,
  price numeric(12,2) not null default 0 check (price >= 0),
  included_stay_days integer not null default 1 check (included_stay_days >= 1),
  doctor_rounds_per_day integer not null default 1 check (doctor_rounds_per_day >= 0),
  includes_room boolean not null default true,
  includes_nursing boolean not null default true,
  includes_consultation boolean not null default true,
  includes_procedure boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (clinic_id,id)
);
create index if not exists ipd_packages_clinic_active_idx on public.ipd_packages(clinic_id,active,name);

create table if not exists public.ipd_admission_packages (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  admission_id uuid not null,
  patient_id uuid not null,
  package_id uuid not null,
  package_name text not null,
  package_amount numeric(12,2) not null check (package_amount >= 0),
  start_date date not null,
  end_date date not null,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (clinic_id,package_id) references public.ipd_packages(clinic_id,id),
  foreign key (admission_id) references public.admissions(id) on delete cascade,
  foreign key (patient_id) references public.patients(id),
  check (end_date >= start_date)
);
create index if not exists ipd_admission_packages_clinic_admission_idx on public.ipd_admission_packages(clinic_id,admission_id,created_at desc);
create unique index if not exists ipd_admission_packages_one_active_idx on public.ipd_admission_packages(admission_id) where status='active';

alter table public.ipd_packages enable row level security;
alter table public.ipd_admission_packages enable row level security;
drop policy if exists ipd_packages_clinic_read on public.ipd_packages;
create policy ipd_packages_clinic_read on public.ipd_packages for select to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','billing','accountant']));
drop policy if exists ipd_packages_admin_write on public.ipd_packages;
create policy ipd_packages_admin_write on public.ipd_packages for all to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin']))
with check (private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists ipd_admission_packages_clinic_read on public.ipd_admission_packages;
create policy ipd_admission_packages_clinic_read on public.ipd_admission_packages for select to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','billing','accountant']));
drop policy if exists ipd_admission_packages_admin_write on public.ipd_admission_packages;
create policy ipd_admission_packages_admin_write on public.ipd_admission_packages for all to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin']))
with check (private.has_clinic_role(clinic_id,array['owner','admin']));

create or replace function public.validate_ipd_admission_package_scope()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_clinic uuid; v_patient uuid;
begin
 select clinic_id,patient_id into v_clinic,v_patient from public.admissions where id=new.admission_id;
 if v_clinic is null or v_clinic<>new.clinic_id or v_patient<>new.patient_id then
   raise exception 'Admission and patient must belong to the selected clinic.';
 end if;
 return new;
end;
$$;
drop trigger if exists trg_validate_ipd_admission_package_scope on public.ipd_admission_packages;
create trigger trg_validate_ipd_admission_package_scope before insert or update on public.ipd_admission_packages
for each row execute function public.validate_ipd_admission_package_scope();
