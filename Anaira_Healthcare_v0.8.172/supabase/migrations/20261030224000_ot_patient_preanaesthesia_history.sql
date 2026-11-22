-- Capture relevant medical/surgical history and anaesthesia assessment at OT booking.
alter table public.operation_theatre_cases
 add column if not exists relevant_medical_history text,
 add column if not exists current_medications text,
 add column if not exists previous_surgeries text,
 add column if not exists pre_anaesthesia_assessment text;
create or replace function public.create_operation_theatre_case_full_v2(
 p_clinic_id uuid,p_patient_id uuid,p_admission_id uuid,p_procedure_catalog_id uuid,p_procedure_name text,p_procedure_code text,p_procedure_category text,p_clinical_indication text,
 p_surgeon_id uuid default null,p_anaesthetist_id uuid default null,p_scheduled_start timestamptz default null,p_scheduled_end timestamptz default null,p_estimated_cost numeric default 0,
 p_operating_room text default null,p_pre_op_diagnosis text default null,p_anaesthesia_type text default null,p_anaesthesia_notes text default null,p_booking_notes text default null,
 p_relevant_medical_history text default null,p_current_medications text default null,p_previous_surgeries text default null,p_pre_anaesthesia_assessment text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_case_id uuid:=gen_random_uuid(); v_invoice_id uuid; v_invoice_no text; v_patient uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Operation Theatre permission required'; end if;
 if coalesce(length(trim(p_procedure_name)),0)<2 then raise exception 'Select or enter a valid procedure'; end if;
 if coalesce(length(trim(p_clinical_indication)),0)<3 then raise exception 'Clinical indication / reason for surgery is required'; end if;
 if p_estimated_cost is null or p_estimated_cost<0 or p_estimated_cost>100000000 then raise exception 'Enter a valid operation estimate'; end if;
 if p_scheduled_start is not null and p_scheduled_end is not null and p_scheduled_end<=p_scheduled_start then raise exception 'Scheduled end must be after scheduled start'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred');
 if v_patient is null or v_patient<>p_patient_id then raise exception 'Select an active IPD admission for the same patient'; end if;
 if p_procedure_catalog_id is not null and not exists(select 1 from public.ot_procedure_catalog where id=p_procedure_catalog_id and clinic_id=p_clinic_id and active) then raise exception 'Procedure is not active in this clinic catalogue'; end if;
 if p_surgeon_id is not null and not exists(select 1 from public.staff_profiles where id=p_surgeon_id and clinic_id=p_clinic_id and active) then raise exception 'Surgeon must belong to this clinic'; end if;
 if p_anaesthetist_id is not null and not exists(select 1 from public.staff_profiles where id=p_anaesthetist_id and clinic_id=p_clinic_id and active) then raise exception 'Anaesthetist must belong to this clinic'; end if;
 insert into public.operation_theatre_cases(id,clinic_id,patient_id,admission_id,procedure_catalog_id,procedure_name,procedure_code,procedure_category,clinical_indication,relevant_medical_history,current_medications,previous_surgeries,pre_anaesthesia_assessment,surgeon_id,anaesthetist_id,scheduled_start,scheduled_end,estimated_cost,estimated_package_cost,operating_room,pre_op_diagnosis,anaesthesia_type,anaesthesia_notes,booking_notes,created_by)
 values(v_case_id,p_clinic_id,p_patient_id,p_admission_id,p_procedure_catalog_id,trim(p_procedure_name),nullif(trim(p_procedure_code),''),nullif(trim(p_procedure_category),''),trim(p_clinical_indication),nullif(trim(p_relevant_medical_history),''),nullif(trim(p_current_medications),''),nullif(trim(p_previous_surgeries),''),nullif(trim(p_pre_anaesthesia_assessment),''),p_surgeon_id,p_anaesthetist_id,p_scheduled_start,p_scheduled_end,p_estimated_cost,p_estimated_cost,nullif(trim(p_operating_room),''),nullif(trim(p_pre_op_diagnosis),''),nullif(trim(p_anaesthesia_type),''),nullif(trim(p_anaesthesia_notes),''),nullif(trim(p_booking_notes),''),v_user);
 if p_estimated_cost>0 then
  v_invoice_id:=gen_random_uuid(); v_invoice_no:='IPD-OT-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice_id::text,'-',''),1,8));
  insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice_id,p_clinic_id,p_patient_id,p_admission_id,v_invoice_no,'issued',p_estimated_cost,p_estimated_cost,0,now(),v_user);
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice_id,'ipd_operation','OT: '||trim(p_procedure_name),1,p_estimated_cost,p_estimated_cost);
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_operation_theatre_case_full','operation_theatre_case',v_case_id::text,jsonb_build_object('patient_id',p_patient_id,'admission_id',p_admission_id,'procedure',p_procedure_name,'category',p_procedure_category,'estimate',p_estimated_cost,'invoice_id',v_invoice_id));
 return jsonb_build_object('case_id',v_case_id,'invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'estimated_cost',p_estimated_cost,'status','planned');
end $$;
revoke all on function public.create_operation_theatre_case_full_v2(uuid,uuid,uuid,uuid,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text,text,text,text,text) from public,anon;
grant execute on function public.create_operation_theatre_case_full_v2(uuid,uuid,uuid,uuid,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text,text,text,text,text) to authenticated;
