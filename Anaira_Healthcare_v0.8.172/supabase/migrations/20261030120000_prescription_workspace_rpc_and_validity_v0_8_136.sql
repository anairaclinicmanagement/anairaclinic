-- Prescription workspace RPC and validity policy (idempotent).
alter table public.prescriptions add column if not exists validity_days integer not null default 7 check (validity_days between 1 and 365);
alter table public.prescriptions add column if not exists valid_until date;
update public.prescriptions set valid_until=(prescribed_at::date + validity_days - 1) where valid_until is null;

create or replace function public.set_clinic_prescription_validity(p_clinic_id uuid,p_validity_days integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin']) then raise exception 'Only clinic owner/admin can change prescription validity'; end if;
 if p_validity_days is null or p_validity_days<1 or p_validity_days>365 then raise exception 'Validity must be between 1 and 365 days'; end if;
 insert into public.clinic_settings(clinic_id,settings,updated_by,updated_at) values(p_clinic_id,jsonb_build_object('prescription_validity_days',p_validity_days),v_user,now())
 on conflict(clinic_id) do update set settings=public.clinic_settings.settings || jsonb_build_object('prescription_validity_days',p_validity_days),updated_by=v_user,updated_at=now();
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,details) values(p_clinic_id,v_user,'update_prescription_validity','clinic_settings',jsonb_build_object('validity_days',p_validity_days));
 return jsonb_build_object('clinic_id',p_clinic_id,'validity_days',p_validity_days);
end $$;
revoke all on function public.set_clinic_prescription_validity(uuid,integer) from public,anon;
grant execute on function public.set_clinic_prescription_validity(uuid,integer) to authenticated;

create or replace function public.create_clinic_prescription(p_clinic_id uuid,p_patient_id uuid,p_items jsonb,p_instructions text default null,p_encounter_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_days integer:=7; v_rx uuid; v_no text; v_item jsonb; v_med_id uuid; v_name text; v_count integer:=0;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor']) then raise exception 'Doctor permission required to issue a prescription'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 if p_encounter_id is not null and not exists(select 1 from public.encounters e where e.id=p_encounter_id and e.clinic_id=p_clinic_id and e.patient_id=p_patient_id) then raise exception 'Encounter does not belong to this patient and clinic'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>50 then raise exception 'Add between 1 and 50 medicine items'; end if;
 select coalesce(nullif(cs.settings->>'prescription_validity_days','')::integer,7) into v_days from public.clinic_settings cs where cs.clinic_id=p_clinic_id;
 v_days:=greatest(1,least(365,coalesce(v_days,7)));
 v_rx:=gen_random_uuid(); v_no:='RX-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_rx::text,'-',''),1,8));
 insert into public.prescriptions(id,clinic_id,encounter_id,patient_id,doctor_id,prescription_no,instructions,status,prescribed_at,validity_days,valid_until)
 values(v_rx,p_clinic_id,p_encounter_id,p_patient_id,(select sp.id from public.staff_profiles sp where sp.user_id=v_user and sp.clinic_id=p_clinic_id limit 1),v_no,nullif(trim(coalesce(p_instructions,'')),''),'signed',now(),v_days,current_date+v_days-1);
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_med_id:=nullif(v_item->>'medication_id','')::uuid; v_name:=nullif(trim(coalesce(v_item->>'medicine_name','')),'');
  if v_med_id is not null then select m.name into v_name from public.medications m where m.id=v_med_id and m.clinic_id=p_clinic_id and m.active=true; if v_name is null then raise exception 'Selected medicine is not active in this clinic'; end if; end if;
  if v_name is null then raise exception 'Medicine name is required'; end if;
  if nullif(v_item->>'duration_days','') is not null and (v_item->>'duration_days')::integer<=0 then raise exception 'Duration must be positive'; end if;
  if nullif(v_item->>'quantity','') is not null and (v_item->>'quantity')::numeric<=0 then raise exception 'Quantity must be positive'; end if;
  insert into public.prescription_items(clinic_id,prescription_id,medication_id,medicine_name,dose,route,frequency,duration_days,quantity,timing_instructions,notes)
  values(p_clinic_id,v_rx,v_med_id,v_name,nullif(v_item->>'dose',''),nullif(v_item->>'route',''),nullif(v_item->>'frequency',''),nullif(v_item->>'duration_days','')::integer,nullif(v_item->>'quantity','')::numeric,nullif(v_item->>'timing_instructions',''),nullif(v_item->>'notes',''));
  v_count:=v_count+1;
 end loop;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_prescription','prescription',v_rx::text,jsonb_build_object('prescription_no',v_no,'patient_id',p_patient_id,'validity_days',v_days,'valid_until',current_date+v_days-1,'items',v_count));
 return jsonb_build_object('id',v_rx,'prescription_no',v_no,'patient_id',p_patient_id,'status','signed','validity_days',v_days,'valid_until',current_date+v_days-1,'item_count',v_count);
end $$;
revoke all on function public.create_clinic_prescription(uuid,uuid,jsonb,text,uuid) from public,anon;
grant execute on function public.create_clinic_prescription(uuid,uuid,jsonb,text,uuid) to authenticated;
notify pgrst,'reload schema';
