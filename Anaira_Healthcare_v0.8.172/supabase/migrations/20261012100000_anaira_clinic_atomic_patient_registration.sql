-- Atomic patient registration hardening for Anaira Clinic.
-- Additive only. Apply only to the dedicated Anaira Clinic Supabase project.
create or replace function public.register_clinic_patient(
  p_clinic_id uuid,
  p_patient jsonb,
  p_allow_possible_duplicate boolean default false
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_phone text;
  v_name text;
  v_dob date;
  v_matches jsonb := '[]'::jsonb;
  v_patient public.patients%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_clinic_role(p_clinic_id, array['owner','admin','doctor','receptionist']) then
    raise exception 'Not authorised to register patients in this clinic';
  end if;
  if p_patient is null or jsonb_typeof(p_patient) <> 'object' then raise exception 'Patient payload is required'; end if;
  v_name := lower(trim(concat_ws(' ', nullif(p_patient->>'first_name',''), nullif(p_patient->>'middle_name',''), nullif(p_patient->>'last_name',''))));
  if v_name = '' then raise exception 'Patient name is required'; end if;
  v_phone := regexp_replace(coalesce(p_patient->>'phone',''), '\D', '', 'g');
  if left(v_phone,2)='91' and length(v_phone)=12 then v_phone := right(v_phone,10); end if;
  if v_phone <> '' and length(v_phone)<10 then raise exception 'Enter a valid mobile number with at least 10 digits'; end if;
  if nullif(p_patient->>'date_of_birth','') is not null then
    begin v_dob := (p_patient->>'date_of_birth')::date;
    exception when others then raise exception 'Invalid date of birth'; end;
    if v_dob > current_date then raise exception 'Date of birth cannot be in the future'; end if;
  end if;
  -- Serialize duplicate checks for the same clinic/mobile to close concurrent-registration races.
  if v_phone <> '' then
    perform pg_advisory_xact_lock(hashtextextended(p_clinic_id::text || ':' || v_phone, 0));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'uhid', p.uhid,
    'full_name', trim(concat_ws(' ',p.first_name,p.middle_name,p.last_name)),
    'phone', p.phone, 'date_of_birth', p.date_of_birth
  ) order by p.created_at desc), '[]'::jsonb)
  into v_matches
  from public.patients p
  where p.clinic_id = p_clinic_id and p.archived_at is null
    and ((v_phone <> '' and regexp_replace(coalesce(p.phone,''), '\D', '', 'g') in (v_phone, '91'||v_phone))
      or (v_dob is not null and lower(trim(concat_ws(' ',p.first_name,p.middle_name,p.last_name)))=v_name and p.date_of_birth=v_dob));
  if jsonb_array_length(v_matches)>0 and not p_allow_possible_duplicate then
    return jsonb_build_object('duplicate_detected', true, 'matches', v_matches);
  end if;
  insert into public.patients(
    clinic_id, branch_id, uhid, first_name, middle_name, last_name, date_of_birth,
    gender, phone, address, allergies, medical_alerts, created_by
  ) values (
    p_clinic_id,
    nullif(p_patient->>'branch_id','')::uuid,
    coalesce(nullif(trim(p_patient->>'uhid'),''), 'AC-'||to_char(current_date,'YYYY')||'-'||upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8))),
    trim(p_patient->>'first_name'), nullif(trim(p_patient->>'middle_name'),''), nullif(trim(p_patient->>'last_name'),''), v_dob,
    case when p_patient->>'gender' in ('female','male','other','unknown') then p_patient->>'gender' else 'unknown' end,
    nullif(trim(p_patient->>'phone'),''), coalesce(p_patient->'address','{}'::jsonb),
    case when jsonb_typeof(p_patient->'allergies')='array' then array(select jsonb_array_elements_text(p_patient->'allergies')) else '{}'::text[] end,
    nullif(trim(p_patient->>'medical_alerts'),''), v_user
  ) returning * into v_patient;
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
  values(p_clinic_id,v_user,'register_patient','patient',v_patient.id::text,jsonb_build_object('uhid',v_patient.uhid,'duplicate_override',p_allow_possible_duplicate));
  return jsonb_build_object('duplicate_detected',false,'patient',to_jsonb(v_patient));
end $$;
revoke all on function public.register_clinic_patient(uuid,jsonb,boolean) from public, anon;
grant execute on function public.register_clinic_patient(uuid,jsonb,boolean) to authenticated;
comment on function public.register_clinic_patient(uuid,jsonb,boolean) is 'Tenant-authorized patient registration with server-side validation, duplicate checks and audit trail.';

-- Tenant-consistency foreign keys: prevent cross-clinic patient/parent references
-- even if an authenticated client guesses another tenant's UUID. NOT VALID leaves
-- legacy rows untouched while enforcing all new inserts/updates immediately.
do $$
declare r record; v_index text; v_constraint text;
begin
  for r in select * from (values
    ('patients','patients'),('appointments','appointments'),('encounters','encounters'),
    ('clinic_branches','clinic_branches'),('staff_profiles','staff_profiles'),('doctor_schedules','doctor_schedules'),
    ('vitals','vitals'),('diagnoses','diagnoses'),('prescriptions','prescriptions'),
    ('medications','medications'),('lab_tests','lab_tests'),('lab_orders','lab_orders'),
    ('services','services'),('invoices','invoices'),('invoice_items','invoice_items'),
    ('rooms','rooms'),('admissions','admissions')
  ) as x(tbl,idx) loop
    v_index := r.idx || '_clinic_id_id_uq';
    execute format('create unique index if not exists %I on public.%I(clinic_id,id)',v_index,r.tbl);
  end loop;
  for r in select * from (values
    ('patients','branch_id','clinic_branches'),('appointments','branch_id','clinic_branches'),
    ('encounters','branch_id','clinic_branches'),('services','branch_id','clinic_branches'),
    ('invoices','branch_id','clinic_branches'),('admissions','branch_id','clinic_branches'),
    ('rooms','branch_id','clinic_branches'),('staff_profiles','branch_id','clinic_branches'),
    ('appointments','doctor_id','staff_profiles'),('encounters','doctor_id','staff_profiles'),
    ('prescriptions','doctor_id','staff_profiles'),('lab_orders','ordered_by','staff_profiles'),
    ('admissions','admitting_doctor_id','staff_profiles'),('doctor_schedules','doctor_id','staff_profiles'),
    ('appointments','patient_id','patients'),
    ('encounters','patient_id','patients'),('encounters','appointment_id','appointments'),
    ('vitals','patient_id','patients'),('vitals','encounter_id','encounters'),
    ('diagnoses','patient_id','patients'),('diagnoses','encounter_id','encounters'),
    ('prescriptions','patient_id','patients'),('prescriptions','encounter_id','encounters'),
    ('lab_orders','patient_id','patients'),('lab_orders','encounter_id','encounters'),
    ('lab_order_items','lab_order_id','lab_orders'),('lab_order_items','lab_test_id','lab_tests'),
    ('invoices','patient_id','patients'),('invoices','encounter_id','encounters'),
    ('invoice_items','invoice_id','invoices'),('invoice_items','service_id','services'),
    ('payments','invoice_id','invoices'),('payments','patient_id','patients'),
    ('insurance_claims','patient_id','patients'),('insurance_claims','invoice_id','invoices'),
    ('admissions','patient_id','patients'),('admissions','room_id','rooms'),('admissions','encounter_id','encounters'),
    ('prescription_items','prescription_id','prescriptions'),('prescription_items','medication_id','medications')
  ) as x(child_table,child_column,parent_table) loop
    v_constraint := r.child_table || '_' || r.child_column || '_same_clinic_fk';
    if not exists(select 1 from pg_constraint where conname=v_constraint and conrelid=('public.'||r.child_table)::regclass) then
      execute format('alter table public.%I add constraint %I foreign key(clinic_id,%I) references public.%I(clinic_id,id) not valid',r.child_table,v_constraint,r.child_column,r.parent_table);
    end if;
  end loop;
end $$;
