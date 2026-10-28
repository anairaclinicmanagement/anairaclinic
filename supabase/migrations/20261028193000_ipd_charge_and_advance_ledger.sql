-- Admission-level charge ledger, advance receipts and lab-to-admission link.
create table if not exists public.ipd_charge_entries (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 admission_id uuid not null references public.admissions(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete restrict,
 charge_type text not null check (charge_type in ('bed','doctor_round','nursing','procedure','lab','radiology','medicine','consumable','service','other')),
 description text not null check (length(trim(description)) between 2 and 300), provider_name text,
 quantity numeric(12,3) not null default 1 check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0),
 amount numeric(12,2) generated always as (round(quantity*unit_price,2)) stored,
 service_at timestamptz not null default now(), source_table text, source_id uuid,
 billed_invoice_id uuid references public.invoices(id) on delete set null, created_by uuid not null default auth.uid(), created_at timestamptz not null default now(), unique(clinic_id,source_table,source_id));
create index if not exists ipd_charge_entries_open_idx on public.ipd_charge_entries(clinic_id,admission_id,service_at) where billed_invoice_id is null;
alter table public.ipd_charge_entries enable row level security;
drop policy if exists ipd_charge_entries_clinical_read on public.ipd_charge_entries;
create policy ipd_charge_entries_clinical_read on public.ipd_charge_entries for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant','pharmacist','lab_technician']));
drop policy if exists ipd_charge_entries_billing_write on public.ipd_charge_entries;
create policy ipd_charge_entries_billing_write on public.ipd_charge_entries for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','accountant','nurse','pharmacist'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','accountant','nurse','pharmacist']));
create table if not exists public.ipd_advance_receipts (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 admission_id uuid not null references public.admissions(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete restrict,
 receipt_no text not null, amount numeric(12,2) not null check(amount>0), applied_amount numeric(12,2) not null default 0 check(applied_amount>=0 and applied_amount<=amount),
 method text not null check(method in ('cash','upi','card','bank_transfer','other')), reference text, notes text,
 received_by uuid not null default auth.uid(), received_at timestamptz not null default now(), unique(clinic_id,receipt_no));
create index if not exists ipd_advance_receipts_open_idx on public.ipd_advance_receipts(clinic_id,admission_id,received_at) where applied_amount<amount;
alter table public.ipd_advance_receipts enable row level security;
drop policy if exists ipd_advance_receipts_clinic_read on public.ipd_advance_receipts;
create policy ipd_advance_receipts_clinic_read on public.ipd_advance_receipts for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant']));
drop policy if exists ipd_advance_receipts_clinic_write on public.ipd_advance_receipts;
create policy ipd_advance_receipts_clinic_write on public.ipd_advance_receipts for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist','accountant'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist','accountant']));
alter table public.lab_orders add column if not exists admission_id uuid references public.admissions(id) on delete set null;
create index if not exists lab_orders_ipd_admission_idx on public.lab_orders(clinic_id,admission_id,ordered_at desc) where admission_id is not null;
