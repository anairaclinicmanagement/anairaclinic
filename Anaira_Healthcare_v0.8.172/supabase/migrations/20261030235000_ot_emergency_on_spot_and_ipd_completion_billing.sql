-- Emergency/on-the-spot OT booking and idempotent IPD ledger posting on recovery/completion.
-- No invoice is created at booking time. The final IPD bill collects this ledger charge.
alter table public.operation_theatre_cases
 add column if not exists surgery_mode text not null default 'scheduled' check (surgery_mode in ('scheduled','emergency')),
 add column if not exists final_operation_charge numeric(14,2),
 add column if not exists billing_charge_entry_id uuid references public.ipd_charge_entries(id) on delete set null,
 add column if not exists billed_to_ipd_at timestamptz;

create or replace function public.create_operation_theatre_case_v3(
 p_clinic_id uuid,p_patient_id uuid,p_admission_id uuid,p_procedure_catalog_id uuid,
 p_procedure_name text,p_procedure_code text,p_procedure_category text,p_clinical_indication text,
 p_surgery_mode text,p_surgeon_id uuid default null,p_anaesthetist_id uuid default null,
 p_scheduled_start timestamptz default null,p_scheduled_end timestamptz default null,
 p_estimated_cost numeric default 0,p_operating_room text default null,p_pre_op_diagnosis text default null,
 p_anaesthesia_type text default null,p_anaesthesia_notes text default null,p_booking_notes text default null,
 p_relevant_medical_history text default null,p_current_medications text default null,p_previous_surgeries text default null,p_pre_anaesthesia_assessment text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_case_id uuid:=gen_random_uuid(); v_patient uuid; v_start timestamptz;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Operation Theatre permission required'; end if;
 if p_surgery_mode not in ('scheduled','emergency') then raise exception 'Select scheduled or emergency OT mode'; end if;
 if coalesce(length(trim(p_procedure_name)),0)<2 or coalesce(length(trim(p_clinical_indication)),0)<3 then raise exception 'Procedure and clinical indication are required'; end if;
 if p_estimated_cost is null or p_estimated_cost<0 or p_estimated_cost>100000000 then raise exception 'Enter a valid estimated charge'; end if;
 if p_scheduled_start is not null and p_scheduled_end is not null and p_scheduled_end<=p_scheduled_start then raise exception 'Scheduled end must be after start'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred');
 if v_patient is null or v_patient<>p_patient_id then raise exception 'Patient must have a matching active IPD admission. Register/admit emergency patient through Emergency/IPD first.'; end if;
 if p_procedure_catalog_id is not null and not exists(select 1 from public.ot_procedure_catalog where id=p_procedure_catalog_id and clinic_id=p_clinic_id and active) then raise exception 'Procedure is not active in this clinic catalogue'; end if;
 if p_surgeon_id is not null and not exists(select 1 from public.staff_profiles where id=p_surgeon_id and clinic_id=p_clinic_id and active) then raise exception 'Surgeon must belong to this clinic'; end if;
 if p_anaesthetist_id is not null and not exists(select 1 from public.staff_profiles where id=p_anaesthetist_id and clinic_id=p_clinic_id and active) then raise exception 'Anaesthetist must belong to this clinic'; end if;
 v_start:=case when p_surgery_mode='emergency' then now() else p_scheduled_start end;
 insert into public.operation_theatre_cases(id,clinic_id,patient_id,admission_id,procedure_catalog_id,procedure_name,procedure_code,procedure_category,clinical_indication,surgery_mode,surgeon_id,anaesthetist_id,scheduled_start,scheduled_end,estimated_cost,estimated_package_cost,operating_room,pre_op_diagnosis,anaesthesia_type,anaesthesia_notes,booking_notes,relevant_medical_history,current_medications,previous_surgeries,pre_anaesthesia_assessment,created_by,status)
 values(v_case_id,p_clinic_id,p_patient_id,p_admission_id,p_procedure_catalog_id,trim(p_procedure_name),nullif(trim(p_procedure_code),''),nullif(trim(p_procedure_category),''),trim(p_clinical_indication),p_surgery_mode,p_surgeon_id,p_anaesthetist_id,v_start,case when p_surgery_mode='emergency' then null else p_scheduled_end end,p_estimated_cost,p_estimated_cost,nullif(trim(p_operating_room),''),nullif(trim(p_pre_op_diagnosis),''),nullif(trim(p_anaesthesia_type),''),nullif(trim(p_anaesthesia_notes),''),nullif(trim(p_booking_notes),''),nullif(trim(p_relevant_medical_history),''),nullif(trim(p_current_medications),''),nullif(trim(p_previous_surgeries),''),nullif(trim(p_pre_anaesthesia_assessment),''),v_user,case when p_surgery_mode='emergency' then 'pre_op' else 'planned' end);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_operation_theatre_case_v3','operation_theatre_case',v_case_id::text,jsonb_build_object('patient_id',p_patient_id,'admission_id',p_admission_id,'procedure',p_procedure_name,'mode',p_surgery_mode,'estimate',p_estimated_cost));
 return jsonb_build_object('case_id',v_case_id,'status',case when p_surgery_mode='emergency' then 'pre_op' else 'planned' end,'surgery_mode',p_surgery_mode,'billing_status','pending_until_completed');
end $$;
revoke all on function public.create_operation_theatre_case_v3(uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text,text,text,text,text) from public,anon;
grant execute on function public.create_operation_theatre_case_v3(uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text,text,text,text,text) to authenticated;

create or replace function public.post_operation_theatre_charge_to_ipd(p_clinic_id uuid,p_case_id uuid,p_final_charge numeric default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_case public.operation_theatre_cases%rowtype; v_charge uuid; v_amount numeric; v_patient uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','accountant']) then raise exception 'OT billing permission required'; end if;
 if p_final_charge is not null and (p_final_charge<0 or p_final_charge>100000000) then raise exception 'Invalid final OT charge'; end if;
 select * into v_case from public.operation_theatre_cases where id=p_case_id and clinic_id=p_clinic_id for update;
 if v_case.id is null then raise exception 'OT case not found'; end if;
 if v_case.status not in ('recovery','completed') then raise exception 'Complete surgery and move the patient to recovery before posting OT charge'; end if;
 if v_case.admission_id is null then raise exception 'This case has no IPD admission. Link/admit patient before billing.'; end if;
 if v_case.billing_charge_entry_id is not null then return jsonb_build_object('charge_entry_id',v_case.billing_charge_entry_id,'status','already_posted','amount',v_case.final_operation_charge); end if;
 v_amount:=coalesce(p_final_charge,v_case.estimated_cost,0);
 if v_amount<=0 then raise exception 'Enter a final OT charge greater than zero'; end if;
 select patient_id into v_patient from public.admissions where id=v_case.admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred');
 if v_patient is null or v_patient<>v_case.patient_id then raise exception 'Active matching IPD admission not found'; end if;
 insert into public.ipd_charge_entries(clinic_id,admission_id,patient_id,charge_type,description,provider_name,quantity,unit_price,service_at,source_table,source_id,created_by)
 values(p_clinic_id,v_case.admission_id,v_case.patient_id,'procedure','Operation Theatre: '||v_case.procedure_name,null,1,v_amount,coalesce(v_case.actual_end,now()),'operation_theatre_cases',v_case.id,auth.uid()) returning id into v_charge;
 update public.operation_theatre_cases set final_operation_charge=v_amount,billing_charge_entry_id=v_charge,billed_to_ipd_at=now(),updated_at=now() where id=v_case.id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,auth.uid(),'post_ot_charge_to_ipd','operation_theatre_case',v_case.id::text,jsonb_build_object('charge_entry_id',v_charge,'amount',v_amount,'admission_id',v_case.admission_id));
 return jsonb_build_object('charge_entry_id',v_charge,'admission_id',v_case.admission_id,'amount',v_amount,'status','posted_to_ipd_ledger');
end $$;
revoke all on function public.post_operation_theatre_charge_to_ipd(uuid,uuid,numeric) from public,anon;
grant execute on function public.post_operation_theatre_charge_to_ipd(uuid,uuid,numeric) to authenticated;
