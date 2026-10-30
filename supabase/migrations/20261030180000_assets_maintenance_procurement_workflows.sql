-- Anaira Healthcare: operational asset, maintenance and procurement workflows.
-- Tenant isolation is enforced through the existing private.has_clinic_role helper.

alter table public.clinic_assets
  add column if not exists brand text,
  add column if not exists model text,
  add column if not exists department text,
  add column if not exists room_number text,
  add column if not exists vendor_name text,
  add column if not exists warranty_start date,
  add column if not exists installation_date date,
  add column if not exists calibration_due date,
  add column if not exists last_service_date date,
  add column if not exists next_service_date date,
  add column if not exists notes text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.maintenance_work_orders
  add column if not exists work_order_no text,
  add column if not exists work_type text not null default 'corrective',
  add column if not exists vendor_name text,
  add column if not exists estimated_cost numeric(14,2) not null default 0,
  add column if not exists actual_cost numeric(14,2) not null default 0,
  add column if not exists parts_used jsonb not null default '[]'::jsonb,
  add column if not exists resolution_notes text,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.asset_service_logs (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  asset_id uuid not null references public.clinic_assets(id) on delete cascade,
  service_type text not null check (service_type in ('preventive','breakdown','calibration','inspection','installation','other')),
  service_date date not null default current_date,
  vendor_name text,
  technician_name text,
  cost numeric(14,2) not null default 0 check (cost >= 0),
  next_due_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.procurement_suppliers (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  supplier_code text not null,
  supplier_name text not null,
  contact_person text,
  phone text,
  email text,
  gstin text,
  address text,
  payment_terms text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (clinic_id, supplier_code)
);

create table if not exists public.purchase_requisitions (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  branch_id uuid references public.clinic_branches(id) on delete set null,
  requisition_no text not null,
  department text,
  requested_by uuid references auth.users(id) on delete set null,
  required_by date,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'draft' check (status in ('draft','submitted','approved','rejected','converted','cancelled')),
  items jsonb not null default '[]'::jsonb,
  estimated_total numeric(14,2) not null default 0 check (estimated_total >= 0),
  purpose text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (clinic_id, requisition_no)
);

create table if not exists public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
  grn_no text not null,
  received_date date not null default current_date,
  invoice_no text,
  received_by uuid references auth.users(id) on delete set null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'received' check (status in ('received','partial','rejected')),
  notes text,
  created_at timestamptz not null default now(),
  unique (clinic_id, grn_no)
);

create index if not exists clinic_assets_due_idx on public.clinic_assets (clinic_id, next_service_date);
create index if not exists maintenance_work_orders_due_idx on public.maintenance_work_orders (clinic_id, status, due_at);
create index if not exists asset_service_logs_asset_date_idx on public.asset_service_logs (clinic_id, asset_id, service_date desc);
create index if not exists procurement_suppliers_name_idx on public.procurement_suppliers (clinic_id, supplier_name);
create index if not exists purchase_requisitions_status_idx on public.purchase_requisitions (clinic_id, status, created_at desc);
create index if not exists goods_receipts_order_idx on public.goods_receipts (clinic_id, purchase_order_id, received_date desc);

alter table public.asset_service_logs enable row level security;
alter table public.procurement_suppliers enable row level security;
alter table public.purchase_requisitions enable row level security;
alter table public.goods_receipts enable row level security;

drop policy if exists asset_service_logs_select on public.asset_service_logs;
create policy asset_service_logs_select on public.asset_service_logs for select to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists asset_service_logs_insert on public.asset_service_logs;
create policy asset_service_logs_insert on public.asset_service_logs for insert to authenticated
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists asset_service_logs_update on public.asset_service_logs;
create policy asset_service_logs_update on public.asset_service_logs for update to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]))
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists asset_service_logs_delete on public.asset_service_logs;
create policy asset_service_logs_delete on public.asset_service_logs for delete to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin}'::text[]));

 drop policy if exists procurement_suppliers_select on public.procurement_suppliers;
create policy procurement_suppliers_select on public.procurement_suppliers for select to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists procurement_suppliers_insert on public.procurement_suppliers;
create policy procurement_suppliers_insert on public.procurement_suppliers for insert to authenticated
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists procurement_suppliers_update on public.procurement_suppliers;
create policy procurement_suppliers_update on public.procurement_suppliers for update to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]))
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists procurement_suppliers_delete on public.procurement_suppliers;
create policy procurement_suppliers_delete on public.procurement_suppliers for delete to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin}'::text[]));

 drop policy if exists purchase_requisitions_select on public.purchase_requisitions;
create policy purchase_requisitions_select on public.purchase_requisitions for select to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists purchase_requisitions_insert on public.purchase_requisitions;
create policy purchase_requisitions_insert on public.purchase_requisitions for insert to authenticated
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists purchase_requisitions_update on public.purchase_requisitions;
create policy purchase_requisitions_update on public.purchase_requisitions for update to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]))
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists purchase_requisitions_delete on public.purchase_requisitions;
create policy purchase_requisitions_delete on public.purchase_requisitions for delete to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin}'::text[]));

 drop policy if exists goods_receipts_select on public.goods_receipts;
create policy goods_receipts_select on public.goods_receipts for select to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists goods_receipts_insert on public.goods_receipts;
create policy goods_receipts_insert on public.goods_receipts for insert to authenticated
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists goods_receipts_update on public.goods_receipts;
create policy goods_receipts_update on public.goods_receipts for update to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]))
with check (private.has_clinic_role(clinic_id, '{owner,admin,accountant,staff}'::text[]));
drop policy if exists goods_receipts_delete on public.goods_receipts;
create policy goods_receipts_delete on public.goods_receipts for delete to authenticated
using (private.has_clinic_role(clinic_id, '{owner,admin}'::text[]));

grant select, insert, update, delete on public.asset_service_logs, public.procurement_suppliers, public.purchase_requisitions, public.goods_receipts to authenticated;
