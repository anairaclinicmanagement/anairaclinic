-- Anaira Clinic Pharmacy Store: expand the existing clinic-scoped catalogue for non-medicine products.
alter table public.medications
  add column if not exists product_category text not null default 'Medicine',
  add column if not exists hsn_code text,
  add column if not exists unit_name text not null default 'Unit',
  add column if not exists manufacturer text;

alter table public.medications drop constraint if exists medications_product_category_check;
alter table public.medications add constraint medications_product_category_check
  check (product_category = any (array['Medicine','OTC','Surgical','Medical Consumable','Personal Care','Baby Care','Wellness','Device','Other']::text[]));
create index if not exists medications_clinic_category_idx on public.medications(clinic_id, product_category);
