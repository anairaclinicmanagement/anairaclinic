-- Real operational workflows for OT, Emergency/Casualty and Ambulance.
-- Additive only; existing records and invoice history are preserved.
alter table public.operation_theatre_cases
  add column if not exists admission_id uuid references public.admissions(id) on delete restrict,
  add column if not exists estimated_cost numeric(12,2) not null default 0;

create index if not exists operation_theatre_cases_admission_idx
  on public.operation_theatre_cases(clinic_id, admission_id, created_at desc);

create or replace function public.create_operation_theatre_case_with_ipd_charge(
 p_clinic_id uuid,
 p_patient_id uuid,
 p_admission_id uuid,
 p_procedure_name text,
 p_surgeon_id uuid default null,
 p_anaesthetist_id uuid default null,
 p_scheduled_start timestamptz default null,
 p_scheduled_end timestamptz default null,
 p_estimated_cost numeric default 0,
 p_pre_op_checklist jsonb default '{}'::jsonb,
 p_anaesthesia_notes text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid := auth.uid();
 v_case_id uuid := gen_random_uuid();
 v_invoice_id uuid;
 v_invoice_no text;
 v_patient uuid;
 v_case public.operation_theatre_cases%rowtype;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then
   raise exception 'Operation Theatre permission required';
 end if;
 if coalesce(length(trim(p_procedure_name)),0)<2 then raise exception 'Procedure name is required'; end if;
 if p_estimated_cost is null or p_estimated_cost<0 or p_estimated_cost>100000000 then raise exception 'Enter a valid operation charge'; end if;
 if p_scheduled_start is not null and p_scheduled_end is not null and p_scheduled_end<=p_scheduled_start then raise exception 'Scheduled end must be after scheduled start'; end if;
 select a.patient_id into v_patient from public.admissions a
 where a.id=p_admission_id and a.clinic_id=p_clinic_id and a.status in ('admitted','transferred');
 if v_patient is null or v_patient<>p_patient_id then raise exception 'Select an active IPD admission for the same patient'; end if;
 if p_surgeon_id is not null and not exists(select 1 from public.staff_profiles s where s.id=p_surgeon_id and s.clinic_id=p_clinic_id and s.active) then raise exception 'Surgeon must belong to this clinic'; end if;
 if p_anaesthetist_id is not null and not exists(select 1 from public.staff_profiles s where s.id=p_anaesthetist_id and s.clinic_id=p_clinic_id and s.active) then raise exception 'Anaesthetist must belong to this clinic'; end if;
 insert into public.operation_theatre_cases(id,clinic_id,patient_id,admission_id,procedure_name,surgeon_id,anaesthetist_id,scheduled_start,scheduled_end,estimated_cost,pre_op_checklist,anaesthesia_notes,created_by)
 values(v_case_id,p_clinic_id,p_patient_id,p_admission_id,trim(p_procedure_name),p_surgeon_id,p_anaesthetist_id,p_scheduled_start,p_scheduled_end,p_estimated_cost,coalesce(p_pre_op_checklist,'{}'::jsonb),nullif(trim(p_anaesthesia_notes),''),v_user)
 returning * into v_case;
 if p_estimated_cost>0 then
   v_invoice_id:=gen_random_uuid();
   v_invoice_no:='IPD-OT-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice_id::text,'-',''),1,8));
   insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
   values(v_invoice_id,p_clinic_id,p_patient_id,p_admission_id,v_invoice_no,'issued',p_estimated_cost,p_estimated_cost,0,now(),v_user);
   insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total)
   values(p_clinic_id,v_invoice_id,'ipd_operation','Operation Theatre: '||trim(p_procedure_name),1,p_estimated_cost,p_estimated_cost);
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_operation_theatre_case','operation_theatre_case',v_case_id::text,jsonb_build_object('patient_id',p_patient_id,'admission_id',p_admission_id,'estimated_cost',p_estimated_cost,'invoice_id',v_invoice_id));
 return jsonb_build_object('case_id',v_case_id,'admission_id',p_admission_id,'invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'estimated_cost',p_estimated_cost,'status',v_case.status);
end $$;
revoke all on function public.create_operation_theatre_case_with_ipd_charge(uuid,uuid,uuid,text,uuid,uuid,timestamptz,timestamptz,numeric,jsonb,text) from public,anon;
grant execute on function public.create_operation_theatre_case_with_ipd_charge(uuid,uuid,uuid,text,uuid,uuid,timestamptz,timestamptz,numeric,jsonb,text) to authenticated;
