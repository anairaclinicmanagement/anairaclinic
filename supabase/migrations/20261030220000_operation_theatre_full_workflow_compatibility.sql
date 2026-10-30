-- Compatibility migration for complete OT surgical workflow.
alter table public.operation_theatre_cases
  add column if not exists anaesthetist_id uuid references public.staff_profiles(id) on delete set null,
  add column if not exists anaesthesia_notes text;
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
-- Structured OT scheduling, safety, operative and recovery documentation.
-- Additive migration: existing OT case data is preserved.
alter table public.operation_theatre_cases
  add column if not exists operating_room text,
  add column if not exists pre_op_diagnosis text,
  add column if not exists asa_class text,
  add column if not exists anaesthesia_type text,
  add column if not exists consent_confirmed boolean not null default false,
  add column if not exists identity_verified boolean not null default false,
  add column if not exists site_marked boolean not null default false,
  add column if not exists fasting_confirmed boolean not null default false,
  add column if not exists allergies_reviewed boolean not null default false,
  add column if not exists instruments_counted boolean not null default false,
  add column if not exists blood_loss_ml integer,
  add column if not exists operative_findings text,
  add column if not exists complications text,
  add column if not exists post_op_plan text,
  add column if not exists recovery_notes text,
  add column if not exists actual_start timestamptz,
  add column if not exists actual_end timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists operation_theatre_cases_schedule_idx
  on public.operation_theatre_cases(clinic_id, scheduled_start, status);
create index if not exists operation_theatre_cases_surgeon_idx
  on public.operation_theatre_cases(clinic_id, surgeon_id, scheduled_start desc);

create or replace function public.update_operation_theatre_case_clinical(
 p_clinic_id uuid, p_case_id uuid, p_status text,
 p_operating_room text default null, p_pre_op_diagnosis text default null,
 p_asa_class text default null, p_anaesthesia_type text default null,
 p_consent_confirmed boolean default false, p_identity_verified boolean default false,
 p_site_marked boolean default false, p_fasting_confirmed boolean default false,
 p_allergies_reviewed boolean default false, p_instruments_counted boolean default false,
 p_operative_notes text default null, p_operative_findings text default null,
 p_blood_loss_ml integer default null, p_complications text default null,
 p_post_op_plan text default null, p_recovery_notes text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_case public.operation_theatre_cases%rowtype; v_now timestamptz := now();
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Operation Theatre permission required'; end if;
 if p_status not in ('planned','pre_op','in_progress','recovery','completed','cancelled') then raise exception 'Invalid OT status'; end if;
 if p_blood_loss_ml is not null and p_blood_loss_ml < 0 then raise exception 'Blood loss cannot be negative'; end if;
 update public.operation_theatre_cases set
   status=p_status, operating_room=nullif(trim(p_operating_room),''),
   pre_op_diagnosis=nullif(trim(p_pre_op_diagnosis),''), asa_class=nullif(trim(p_asa_class),''),
   anaesthesia_type=nullif(trim(p_anaesthesia_type),''), consent_confirmed=coalesce(p_consent_confirmed,false),
   identity_verified=coalesce(p_identity_verified,false), site_marked=coalesce(p_site_marked,false),
   fasting_confirmed=coalesce(p_fasting_confirmed,false), allergies_reviewed=coalesce(p_allergies_reviewed,false),
   instruments_counted=coalesce(p_instruments_counted,false), operative_notes=p_operative_notes,
   operative_findings=p_operative_findings, blood_loss_ml=p_blood_loss_ml, complications=p_complications,
   post_op_plan=p_post_op_plan, recovery_notes=p_recovery_notes,
   actual_start=case when p_status='in_progress' and actual_start is null then v_now else actual_start end,
   actual_end=case when p_status in ('recovery','completed') and actual_end is null then v_now else actual_end end,
   updated_at=v_now
 where id=p_case_id and clinic_id=p_clinic_id returning * into v_case;
 if v_case.id is null then raise exception 'OT case not found in this clinic'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,auth.uid(),'update_operation_theatre_case','operation_theatre_case',p_case_id::text,
 jsonb_build_object('status',p_status,'operating_room',p_operating_room));
 return jsonb_build_object('case_id',v_case.id,'status',v_case.status,'updated_at',v_case.updated_at);
end $$;
revoke all on function public.update_operation_theatre_case_clinical(uuid,uuid,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean,text,text,integer,text,text,text) from public,anon;
grant execute on function public.update_operation_theatre_case_clinical(uuid,uuid,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean,text,text,integer,text,text,text) to authenticated;
