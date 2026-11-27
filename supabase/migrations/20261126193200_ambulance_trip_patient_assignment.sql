-- Assign or correct the patient link on an existing ambulance trip without moving tenant data.
create or replace function public.assign_ambulance_trip_patient(p_clinic_id uuid,p_trip_id uuid,p_patient_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_trip public.ambulance_trips%rowtype; v_user uuid := auth.uid();
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','receptionist','billing','accountant','ambulance','emergency']) then raise exception 'Ambulance patient assignment permission required'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Select an active patient from this clinic'; end if;
 select * into v_trip from public.ambulance_trips t where t.id=p_trip_id and t.clinic_id=p_clinic_id for update;
 if not found then raise exception 'Ambulance trip not found in this clinic'; end if;
 if v_trip.invoice_id is not null then raise exception 'Patient cannot be changed after the trip has been invoiced'; end if;
 update public.ambulance_trips set patient_id=p_patient_id where id=p_trip_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'assign_ambulance_trip_patient','ambulance_trip',p_trip_id::text,jsonb_build_object('patient_id',p_patient_id));
 return jsonb_build_object('trip_id',p_trip_id,'patient_id',p_patient_id,'assigned',true);
end $$;
revoke all on function public.assign_ambulance_trip_patient(uuid,uuid,uuid) from public,anon;
grant execute on function public.assign_ambulance_trip_patient(uuid,uuid,uuid) to authenticated;
