-- Fix schema drift between older ambulance_trips installations and the current app.
-- Additive/idempotent: keeps existing trip data and makes current column names available.
alter table public.ambulance_trips
  add column if not exists pickup_address text,
  add column if not exists destination_address text,
  add column if not exists dispatch_at timestamptz,
  add column if not exists arrival_at timestamptz,
  add column if not exists return_at timestamptz;

-- Older deployments used pickup_location/dropoff_location and dispatched_at/arrived_at/completed_at.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='ambulance_trips' and column_name='pickup_location') then
    execute $sql$update public.ambulance_trips set pickup_address = coalesce(nullif(pickup_address, ''), pickup_location) where pickup_address is null or pickup_address = ''$sql$;
    execute 'alter table public.ambulance_trips alter column pickup_location drop not null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='ambulance_trips' and column_name='dropoff_location') then
    execute $sql$update public.ambulance_trips set destination_address = coalesce(nullif(destination_address, ''), dropoff_location) where destination_address is null or destination_address = ''$sql$;
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='ambulance_trips' and column_name='dispatched_at') then
    execute 'update public.ambulance_trips set dispatch_at = coalesce(dispatch_at, dispatched_at) where dispatch_at is null';
    execute 'alter table public.ambulance_trips alter column dispatched_at drop not null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='ambulance_trips' and column_name='arrived_at') then
    execute 'update public.ambulance_trips set arrival_at = coalesce(arrival_at, arrived_at) where arrival_at is null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='ambulance_trips' and column_name='completed_at') then
    execute 'update public.ambulance_trips set return_at = coalesce(return_at, completed_at) where return_at is null';
  end if;
end $$;

create index if not exists ambulance_trips_clinic_pickup_address_idx
  on public.ambulance_trips (clinic_id, created_at desc);
