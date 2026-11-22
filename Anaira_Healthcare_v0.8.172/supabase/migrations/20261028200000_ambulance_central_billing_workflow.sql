-- Anaira: ambulance trips are operational records only. All invoicing/payment is centralised in Billing & Payments.
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
 v_trip_id uuid := gen_random_uuid(); v_hospital_cost numeric(12,2); v_patient_charge numeric(12,2);
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
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_ambulance_trip','ambulance_trip',v_trip_id::text,jsonb_build_object('vehicle_id',p_vehicle_id,'ownership_type',v_vehicle.ownership_type,'distance_km',p_distance_km,'hospital_cost',v_hospital_cost,'estimated_patient_charge',v_patient_charge,'billing_deferred_to_central_billing',true,'emergency_visit_id',p_emergency_visit_id));
 return jsonb_build_object('trip_id',v_trip_id,'invoice_id',null,'invoice_no',null,'distance_km',p_distance_km,'hospital_cost',v_hospital_cost,'patient_charge',v_patient_charge,'status',case when p_dispatch_at is null then 'requested' else 'dispatched' end);
end $$;
revoke all on function public.create_ambulance_trip_with_billing(uuid,uuid,uuid,uuid,text,text,numeric,numeric,numeric,text,timestamptz) from public, anon;
grant execute on function public.create_ambulance_trip_with_billing(uuid,uuid,uuid,uuid,text,text,numeric,numeric,numeric,text,timestamptz) to authenticated;

create or replace function public.create_ambulance_invoice_from_billing(p_clinic_id uuid, p_trip_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid := auth.uid(); v_trip public.ambulance_trips%rowtype; v_invoice_id uuid := gen_random_uuid(); v_invoice_no text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','billing','accountant']) then raise exception 'Billing permission required'; end if;
 select * into v_trip from public.ambulance_trips where id=p_trip_id and clinic_id=p_clinic_id for update;
 if not found then raise exception 'Ambulance trip not found in this clinic'; end if;
 if v_trip.invoice_id is not null then raise exception 'This ambulance trip is already linked to an invoice'; end if;
 if v_trip.patient_id is null then raise exception 'Assign a patient to this trip before billing'; end if;
 if coalesce(v_trip.patient_charge,0)<=0 then raise exception 'Estimated patient charge must be greater than zero'; end if;
 if v_trip.status not in ('completed','cancelled') then raise exception 'Complete the trip before creating its invoice'; end if;
 if not exists(select 1 from public.patients where id=v_trip.patient_id and clinic_id=p_clinic_id) then raise exception 'Patient does not belong to this clinic'; end if;
 v_invoice_no:='AMB-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice_id::text,'-',''),1,8));
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
 values(v_invoice_id,p_clinic_id,v_trip.patient_id,v_invoice_no,'issued',v_trip.patient_charge,v_trip.patient_charge,0,now(),v_user);
 insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total)
 values(p_clinic_id,v_invoice_id,'ambulance_transport','Ambulance transport · '||v_trip.vehicle_code||' · '||v_trip.distance_km::text||' km',1,v_trip.patient_charge,v_trip.patient_charge);
 update public.ambulance_trips set invoice_id=v_invoice_id where id=v_trip.id and clinic_id=p_clinic_id and invoice_id is null;
 if not found then raise exception 'Trip invoice link changed; transaction rolled back'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_ambulance_invoice','invoice',v_invoice_id::text,jsonb_build_object('trip_id',v_trip.id,'invoice_no',v_invoice_no,'amount',v_trip.patient_charge));
 return jsonb_build_object('invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'total_amount',v_trip.patient_charge,'trip_id',v_trip.id);
end $$;
revoke all on function public.create_ambulance_invoice_from_billing(uuid,uuid) from public, anon;
grant execute on function public.create_ambulance_invoice_from_billing(uuid,uuid) to authenticated;
