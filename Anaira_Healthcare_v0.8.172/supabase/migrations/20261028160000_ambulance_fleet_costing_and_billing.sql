-- Fleet/provider register, kilometre costing, emergency linkage and atomic patient billing.
-- Additive migration: preserves existing ambulance trip and invoice records.
create table if not exists public.ambulance_vehicles (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 vehicle_code text not null,
 ownership_type text not null check (ownership_type in ('hospital_owned','hired')),
 provider_name text,
 driver_name text,
 cost_per_km numeric(12,2) not null default 0 check (cost_per_km >= 0),
 default_patient_charge_per_km numeric(12,2) not null default 0 check (default_patient_charge_per_km >= 0),
 fixed_hire_cost numeric(12,2) not null default 0 check (fixed_hire_cost >= 0),
 active boolean not null default true,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (clinic_id, vehicle_code),
 check (ownership_type <> 'hired' or nullif(trim(provider_name),'') is not null)
);

alter table public.ambulance_trips
 add column if not exists vehicle_id uuid references public.ambulance_vehicles(id) on delete set null,
 add column if not exists ownership_type text check (ownership_type is null or ownership_type in ('patient_own','hospital_owned','hired')),
 add column if not exists emergency_visit_id uuid references public.emergency_visits(id) on delete set null,
 add column if not exists distance_km numeric(12,2) not null default 0 check (distance_km >= 0),
 add column if not exists hospital_cost numeric(12,2) not null default 0 check (hospital_cost >= 0),
 add column if not exists patient_charge numeric(12,2) not null default 0 check (patient_charge >= 0),
 add column if not exists invoice_id uuid references public.invoices(id) on delete set null;

create index if not exists ambulance_vehicles_clinic_active_idx on public.ambulance_vehicles(clinic_id, active, ownership_type);
create index if not exists ambulance_trips_emergency_idx on public.ambulance_trips(clinic_id, emergency_visit_id);
create index if not exists ambulance_trips_invoice_idx on public.ambulance_trips(clinic_id, invoice_id);

alter table public.ambulance_vehicles enable row level security;
drop policy if exists ambulance_vehicles_clinic_read on public.ambulance_vehicles;
create policy ambulance_vehicles_clinic_read on public.ambulance_vehicles for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','billing','ambulance','emergency']));
drop policy if exists ambulance_vehicles_clinic_write on public.ambulance_vehicles;
create policy ambulance_vehicles_clinic_write on public.ambulance_vehicles for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','ambulance','emergency'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','ambulance','emergency']));
grant select, insert, update on public.ambulance_vehicles to authenticated;

create or replace function public.create_ambulance_trip_with_billing(
 p_clinic_id uuid,
 p_vehicle_id uuid,
 p_patient_id uuid default null,
 p_emergency_visit_id uuid default null,
 p_pickup_address text default '',
 p_destination_address text default null,
 p_distance_km numeric default 0,
 p_patient_charge_per_km numeric default 0,
 p_fixed_hire_cost numeric default 0,
 p_notes text default null,
 p_dispatch_at timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid := auth.uid(); v_vehicle public.ambulance_vehicles%rowtype;
 v_trip_id uuid := gen_random_uuid(); v_invoice_id uuid; v_invoice_no text;
 v_hospital_cost numeric(12,2); v_patient_charge numeric(12,2);
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','receptionist','billing','ambulance','emergency']) then raise exception 'Ambulance permission required'; end if;
 if coalesce(length(trim(p_pickup_address)),0)<2 then raise exception 'Pickup location is required'; end if;
 if p_distance_km is null or p_distance_km<0 or p_distance_km>100000 then raise exception 'Enter a valid trip distance'; end if;
 if p_patient_charge_per_km is null or p_patient_charge_per_km<0 or p_fixed_hire_cost is null or p_fixed_hire_cost<0 then raise exception 'Enter valid non-negative charges'; end if;
 select * into v_vehicle from public.ambulance_vehicles where id=p_vehicle_id and clinic_id=p_clinic_id and active for update;
 if not found then raise exception 'Selected ambulance/provider is not active in this clinic'; end if;
 if p_patient_id is not null and not exists(select 1 from public.patients where id=p_patient_id and clinic_id=p_clinic_id) then raise exception 'Patient does not belong to this clinic'; end if;
 if p_emergency_visit_id is not null and not exists(select 1 from public.emergency_visits where id=p_emergency_visit_id and clinic_id=p_clinic_id and patient_id=p_patient_id) then raise exception 'Emergency visit and patient do not match'; end if;
 v_hospital_cost:=round((p_distance_km*v_vehicle.cost_per_km)+p_fixed_hire_cost,2);
 v_patient_charge:=round((p_distance_km*p_patient_charge_per_km)+p_fixed_hire_cost,2);
 insert into public.ambulance_trips(id,clinic_id,patient_id,vehicle_code,driver_name,pickup_address,destination_address,dispatch_at,status,notes,created_by,vehicle_id,ownership_type,emergency_visit_id,distance_km,hospital_cost,patient_charge)
 values(v_trip_id,p_clinic_id,p_patient_id,v_vehicle.vehicle_code,v_vehicle.driver_name,trim(p_pickup_address),nullif(trim(coalesce(p_destination_address,'')),''),p_dispatch_at,case when p_dispatch_at is null then 'requested' else 'dispatched' end,nullif(trim(coalesce(p_notes,'')),''),v_user,p_vehicle_id,v_vehicle.ownership_type,p_emergency_visit_id,p_distance_km,v_hospital_cost,v_patient_charge);
 if p_patient_id is not null and v_patient_charge>0 then
  v_invoice_id:=gen_random_uuid();
  v_invoice_no:='AMB-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice_id::text,'-',''),1,8));
  insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
  values(v_invoice_id,p_clinic_id,p_patient_id,v_invoice_no,'issued',v_patient_charge,v_patient_charge,0,now(),v_user);
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total)
  values(p_clinic_id,v_invoice_id,'ambulance_transport','Ambulance transport ('||p_distance_km::text||' km)',1,v_patient_charge,v_patient_charge);
  update public.ambulance_trips set invoice_id=v_invoice_id where id=v_trip_id;
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_ambulance_trip','ambulance_trip',v_trip_id::text,jsonb_build_object('vehicle_id',p_vehicle_id,'ownership_type',v_vehicle.ownership_type,'distance_km',p_distance_km,'hospital_cost',v_hospital_cost,'patient_charge',v_patient_charge,'invoice_id',v_invoice_id,'emergency_visit_id',p_emergency_visit_id));
 return jsonb_build_object('trip_id',v_trip_id,'invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'distance_km',p_distance_km,'hospital_cost',v_hospital_cost,'patient_charge',v_patient_charge,'status',case when p_dispatch_at is null then 'requested' else 'dispatched' end);
end $$;
revoke all on function public.create_ambulance_trip_with_billing(uuid,uuid,uuid,uuid,text,text,numeric,numeric,numeric,text,timestamptz) from public, anon;
grant execute on function public.create_ambulance_trip_with_billing(uuid,uuid,uuid,uuid,text,text,numeric,numeric,numeric,text,timestamptz) to authenticated;
