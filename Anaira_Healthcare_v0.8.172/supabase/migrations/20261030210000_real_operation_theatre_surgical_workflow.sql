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
