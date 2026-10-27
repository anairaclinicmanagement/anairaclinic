-- Transactional room capacity, admission and discharge operations.
create or replace function public.create_clinic_admission(p_clinic_id uuid,p_patient_id uuid,p_room_id uuid,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_bed_count integer; v_occupied integer; v_admission uuid; v_no text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'IPD admission permission required'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 select r.bed_count into v_bed_count from public.rooms r where r.id=p_room_id and r.clinic_id=p_clinic_id and r.active=true for update;
 if v_bed_count is null then raise exception 'Active room not found in this clinic'; end if;
 select count(*) into v_occupied from public.admissions a where a.clinic_id=p_clinic_id and a.room_id=p_room_id and a.status in ('admitted','transferred');
 if v_occupied>=v_bed_count then raise exception 'No bed capacity available in this room'; end if;
 v_admission:=gen_random_uuid(); v_no:='ADM-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.admissions(id,clinic_id,patient_id,room_id,admission_no,status,admitted_at,notes) values(v_admission,p_clinic_id,p_patient_id,p_room_id,v_no,'admitted',now(),nullif(trim(coalesce(p_notes,'')),''));
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_admission','admission',v_admission::text,jsonb_build_object('admission_no',v_no,'patient_id',p_patient_id,'room_id',p_room_id));
 return jsonb_build_object('id',v_admission,'admission_no',v_no,'patient_id',p_patient_id,'room_id',p_room_id,'status','admitted');
end $$;
revoke all on function public.create_clinic_admission(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.create_clinic_admission(uuid,uuid,uuid,text) to authenticated;

create or replace function public.discharge_clinic_admission(p_clinic_id uuid,p_admission_id uuid,p_summary text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_status text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'IPD discharge permission required'; end if;
 if coalesce(trim(p_summary),'')='' then raise exception 'Discharge summary is required'; end if;
 update public.admissions set status='discharged',discharged_at=now(),discharge_summary=trim(p_summary) where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred') returning status into v_status;
 if v_status is null then raise exception 'Active admission not found in this clinic'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'discharge_admission','admission',p_admission_id::text,jsonb_build_object('summary_length',length(trim(p_summary))));
 return jsonb_build_object('id',p_admission_id,'status',v_status,'discharged_at',now());
end $$;
revoke all on function public.discharge_clinic_admission(uuid,uuid,text) from public,anon;
grant execute on function public.discharge_clinic_admission(uuid,uuid,text) to authenticated;
