create table if not exists public.ipd_clinical_records (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 admission_id uuid not null references public.admissions(id) on delete cascade, patient_id uuid not null references public.patients(id) on delete cascade,
 record_type text not null check (record_type in ('doctor_visit','initial_assessment','diagnosis','progress_note','doctor_order','treatment_plan','consultant_note','follow_up')),
 assessment text, diagnosis text, treatment_plan text, doctor_orders text, follow_up_date date,
 observations jsonb not null default '{}'::jsonb, notes text, recorded_by uuid not null references auth.users(id), recorded_at timestamptz not null default now());
create index if not exists ipd_clinical_records_clinic_admission_idx on public.ipd_clinical_records(clinic_id,admission_id,recorded_at desc);
alter table public.ipd_clinical_records enable row level security;
drop policy if exists ipd_clinical_records_select on public.ipd_clinical_records;
create policy ipd_clinical_records_select on public.ipd_clinical_records for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist']));
create or replace function public.create_ipd_clinical_record(p_clinic_id uuid,p_admission_id uuid,p_record_type text,p_assessment text default null,p_diagnosis text default null,p_treatment_plan text default null,p_doctor_orders text default null,p_follow_up_date date default null,p_observations jsonb default '{}'::jsonb,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_status text; v_id uuid:=gen_random_uuid();
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor']) then raise exception 'Doctor clinical-record permission required'; end if;
 if p_record_type not in ('doctor_visit','initial_assessment','diagnosis','progress_note','doctor_order','treatment_plan','consultant_note','follow_up') then raise exception 'Unsupported clinical record type'; end if;
 select a.patient_id,a.status into v_patient,v_status from public.admissions a where a.id=p_admission_id and a.clinic_id=p_clinic_id;
 if v_patient is null or v_status not in ('admitted','transferred') then raise exception 'Active admission not found in this clinic'; end if;
 if length(coalesce(p_assessment,''))+length(coalesce(p_diagnosis,''))+length(coalesce(p_treatment_plan,''))+length(coalesce(p_doctor_orders,''))+length(coalesce(p_notes,''))=0 then raise exception 'Enter clinical assessment, diagnosis, plan, orders or notes'; end if;
 insert into public.ipd_clinical_records(id,clinic_id,admission_id,patient_id,record_type,assessment,diagnosis,treatment_plan,doctor_orders,follow_up_date,observations,notes,recorded_by)
 values(v_id,p_clinic_id,p_admission_id,v_patient,p_record_type,nullif(trim(coalesce(p_assessment,'')),''),nullif(trim(coalesce(p_diagnosis,'')),''),nullif(trim(coalesce(p_treatment_plan,'')),''),nullif(trim(coalesce(p_doctor_orders,'')),''),p_follow_up_date,coalesce(p_observations,'{}'::jsonb),nullif(trim(coalesce(p_notes,'')),''),v_user);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_ipd_clinical_record','ipd_clinical_record',v_id::text,jsonb_build_object('admission_id',p_admission_id,'patient_id',v_patient,'record_type',p_record_type));
 return jsonb_build_object('id',v_id,'admission_id',p_admission_id,'patient_id',v_patient,'record_type',p_record_type,'recorded_at',now());
end $$;
revoke all on function public.create_ipd_clinical_record(uuid,uuid,text,text,text,text,text,date,jsonb,text) from public,anon;
grant execute on function public.create_ipd_clinical_record(uuid,uuid,text,text,text,text,text,date,jsonb,text) to authenticated;
