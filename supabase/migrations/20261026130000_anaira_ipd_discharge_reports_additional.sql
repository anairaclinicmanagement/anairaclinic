create table if not exists public.ipd_discharge_records (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 admission_id uuid not null references public.admissions(id) on delete cascade,
 patient_id uuid not null references public.patients(id) on delete cascade,
 discharge_type text not null default 'routine' check (discharge_type in ('routine','referred','lama','absconded','death','transfer')),
 final_diagnosis text not null,
 treatment_summary text not null,
 medicines_on_discharge text not null default '',
 follow_up_date date,
 investigation_summary text not null default '',
 doctor_instructions text not null default '',
 final_bill_cleared boolean not null default false,
 status text not null default 'draft' check (status in ('draft','approved')),
 created_by uuid not null references auth.users(id),
 approved_by uuid references auth.users(id),
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (clinic_id, admission_id)
);
create index if not exists ipd_discharge_records_clinic_date_idx on public.ipd_discharge_records(clinic_id, created_at desc);
alter table public.ipd_discharge_records enable row level security;
drop policy if exists ipd_discharge_records_select on public.ipd_discharge_records;
create policy ipd_discharge_records_select on public.ipd_discharge_records for select to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant']));
create or replace function public.save_ipd_discharge_workflow(
 p_clinic_id uuid,p_admission_id uuid,p_discharge_type text,p_final_diagnosis text,p_treatment_summary text,
 p_medicines_on_discharge text default '',p_follow_up_date date default null,p_investigation_summary text default '',
 p_doctor_instructions text default '',p_approve boolean default false
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_status text; v_record_id uuid; v_due numeric:=0;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'IPD discharge permission required'; end if;
 if p_discharge_type not in ('routine','referred','lama','absconded','death','transfer') then raise exception 'Invalid discharge type'; end if;
 if coalesce(trim(p_final_diagnosis),'')='' then raise exception 'Final diagnosis is required'; end if;
 if coalesce(trim(p_treatment_summary),'')='' then raise exception 'Treatment summary is required'; end if;
 select a.patient_id,a.status into v_patient,v_status from public.admissions a where a.id=p_admission_id and a.clinic_id=p_clinic_id;
 if v_patient is null then raise exception 'Admission not found in this clinic'; end if;
 if v_status not in ('admitted','transferred') then raise exception 'Admission is not active'; end if;
 select coalesce(sum(greatest(i.total_amount-i.paid_amount,0)),0) into v_due from public.invoices i where i.clinic_id=p_clinic_id and i.admission_id=p_admission_id and i.status not in ('void','refunded','cancelled');
 if coalesce(p_approve,false) and v_due > 0 then raise exception 'Final bill is not cleared. Outstanding balance: ₹%',round(v_due,2); end if;
 insert into public.ipd_discharge_records(clinic_id,admission_id,patient_id,discharge_type,final_diagnosis,treatment_summary,medicines_on_discharge,follow_up_date,investigation_summary,doctor_instructions,final_bill_cleared,status,created_by,approved_by,approved_at,updated_at)
 values(p_clinic_id,p_admission_id,v_patient,p_discharge_type,trim(p_final_diagnosis),trim(p_treatment_summary),coalesce(trim(p_medicines_on_discharge),''),p_follow_up_date,coalesce(trim(p_investigation_summary),''),coalesce(trim(p_doctor_instructions),''),v_due=0,case when coalesce(p_approve,false) then 'approved' else 'draft' end,v_user,case when coalesce(p_approve,false) then v_user else null end,case when coalesce(p_approve,false) then now() else null end,now())
 on conflict (clinic_id,admission_id) do update set discharge_type=excluded.discharge_type,final_diagnosis=excluded.final_diagnosis,treatment_summary=excluded.treatment_summary,medicines_on_discharge=excluded.medicines_on_discharge,follow_up_date=excluded.follow_up_date,investigation_summary=excluded.investigation_summary,doctor_instructions=excluded.doctor_instructions,final_bill_cleared=excluded.final_bill_cleared,status=excluded.status,approved_by=excluded.approved_by,approved_at=excluded.approved_at,updated_at=now() returning id into v_record_id;
 if coalesce(p_approve,false) then
  update public.admissions set status='discharged',discharged_at=now(),discharge_summary=trim(p_final_diagnosis)||E'\n\n'||trim(p_treatment_summary) where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred');
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'approve_ipd_discharge','admission',p_admission_id::text,jsonb_build_object('discharge_record_id',v_record_id,'discharge_type',p_discharge_type,'final_bill_cleared',true));
 else
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'save_ipd_discharge_draft','ipd_discharge_record',v_record_id::text,jsonb_build_object('admission_id',p_admission_id,'discharge_type',p_discharge_type));
 end if;
 return jsonb_build_object('id',v_record_id,'admission_id',p_admission_id,'patient_id',v_patient,'status',case when coalesce(p_approve,false) then 'approved' else 'draft' end,'final_bill_cleared',v_due=0,'outstanding_balance',round(v_due,2));
end $$;
revoke all on function public.save_ipd_discharge_workflow(uuid,uuid,text,text,text,text,date,text,text,boolean) from public,anon;
grant execute on function public.save_ipd_discharge_workflow(uuid,uuid,text,text,text,text,date,text,text,boolean) to authenticated;
