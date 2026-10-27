-- Allow Receptionist to perform admission from the IPD reception workflow.
create or replace function public.create_clinic_admission_v2(
 p_clinic_id uuid,p_patient_id uuid,p_bed_id uuid,p_notes text default null,
 p_admission_type text default 'routine',p_referred_by text default null,
 p_provisional_diagnosis text default null,p_department text default null,
 p_consultant_name text default null,p_attendant_name text default null,
 p_attendant_relation text default null,p_attendant_phone text default null,
 p_admitted_at timestamptz default now()
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_room uuid; v_bed_number text; v_admission uuid:=gen_random_uuid(); v_no text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','receptionist']) then raise exception 'IPD admission permission required'; end if;
 if p_admission_type not in ('routine','emergency','daycare','maternity','transfer') then raise exception 'Invalid admission type'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 select b.room_id,b.bed_number into v_room,v_bed_number from public.room_beds b join public.rooms r on r.id=b.room_id and r.clinic_id=b.clinic_id and r.active=true where b.id=p_bed_id and b.clinic_id=p_clinic_id and b.active=true for update of b;
 if v_room is null then raise exception 'Active bed not found in this clinic'; end if;
 if exists(select 1 from public.admissions a where a.clinic_id=p_clinic_id and a.bed_id=p_bed_id and a.status in ('admitted','transferred')) then raise exception 'This bed has already been allocated'; end if;
 v_no:='IPD-'||to_char(coalesce(p_admitted_at,now()) at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.admissions(id,clinic_id,patient_id,room_id,bed_id,admission_no,status,admitted_at,notes,admission_type,referred_by,provisional_diagnosis,department,consultant_name,attendant_name,attendant_relation,attendant_phone)
 values(v_admission,p_clinic_id,p_patient_id,v_room,p_bed_id,v_no,'admitted',coalesce(p_admitted_at,now()),nullif(trim(coalesce(p_notes,'')),''),p_admission_type,nullif(trim(coalesce(p_referred_by,'')),''),nullif(trim(coalesce(p_provisional_diagnosis,'')),''),nullif(trim(coalesce(p_department,'')),''),nullif(trim(coalesce(p_consultant_name,'')),''),nullif(trim(coalesce(p_attendant_name,'')),''),nullif(trim(coalesce(p_attendant_relation,'')),''),nullif(trim(coalesce(p_attendant_phone,'')),''));
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_admission','admission',v_admission::text,jsonb_build_object('admission_no',v_no,'patient_id',p_patient_id,'room_id',v_room,'bed_id',p_bed_id,'bed_number',v_bed_number,'admission_type',p_admission_type));
 return jsonb_build_object('id',v_admission,'admission_no',v_no,'patient_id',p_patient_id,'room_id',v_room,'bed_id',p_bed_id,'bed_number',v_bed_number,'status','admitted');
end $$;
revoke all on function public.create_clinic_admission_v2(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) from public,anon;
grant execute on function public.create_clinic_admission_v2(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) to authenticated;
