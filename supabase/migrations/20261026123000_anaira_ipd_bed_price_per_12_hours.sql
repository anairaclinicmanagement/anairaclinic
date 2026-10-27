-- Store a tariff per physical bed for every started 12-hour stay block.
alter table public.room_beds
  add column if not exists price_per_12_hours numeric(12,2) not null default 0;

alter table public.room_beds
  drop constraint if exists room_beds_price_per_12_hours_check;
alter table public.room_beds
  add constraint room_beds_price_per_12_hours_check
  check (price_per_12_hours >= 0);

create index if not exists room_beds_clinic_price_idx
  on public.room_beds(clinic_id, price_per_12_hours);
