-- Anaira Healthcare Management System: multiple facility types per clinic/hospital.
-- Additive migration; preserves existing tenant data and uses platform-admin authorization.
alter table public.clinics
  add column if not exists facility_types text[] not null default array[]::text[];

update public.clinics
set facility_types = array[clinic_type]
where cardinality(coalesce(facility_types, array[]::text[])) = 0;

create or replace function public.platform_admin_set_clinic_facility_types(
  p_clinic_id uuid,
  p_facility_types text[]
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_types text[] := coalesce(p_facility_types, array[]::text[]);
  v_allowed text[] := array[
    'general_opd','general_medicine','dental','orthodontics','oral_surgery','periodontics','prosthodontics',
    'eye','ophthalmology','optometry','skin','dermatology','cosmetology','pediatrics','neonatology',
    'gynecology','obstetrics','fertility','orthopedic','sports_medicine','physiotherapy','neurology',
    'cardiology','diabetology','endocrinology','gastroenterology','pulmonology','nephrology','urology',
    'ENT','ent','psychiatry','psychology','oncology','rheumatology','geriatrics','pain_management',
    'ayurveda','homeopathy','unani','siddha','naturopathy','diagnostic_lab','radiology_centre',
    'pathology_lab','imaging_centre','dialysis_centre','vaccination_centre','urgent_care','polyclinic',
    'nursing_home','maternity_home','day_care_centre','rehabilitation_centre','fertility_centre',
    'eye_hospital','dental_hospital','hospital','multi_specialty_hospital','super_specialty_hospital','other'
  ];
begin
  if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
  if cardinality(v_types) < 1 or cardinality(v_types) > 20 then raise exception 'Select between 1 and 20 facility types'; end if;
  if exists(select 1 from unnest(v_types) t where not (t = any(v_allowed))) then raise exception 'Unsupported facility type'; end if;
  select array_agg(x order by first_ord) into v_types
  from (select t as x, min(ord) as first_ord from unnest(v_types) with ordinality u(t,ord) group by t) d;
  update public.clinics
  set facility_types = v_types,
      clinic_type = v_types[1],
      clinic_profile = coalesce(clinic_profile, '{}'::jsonb) || jsonb_build_object('facility_types', v_types),
      updated_at = now()
  where id = p_clinic_id;
  if not found then raise exception 'Clinic not found'; end if;
  insert into public.platform_audit_logs(actor_user_id, action, entity_type, entity_id, details)
  values(auth.uid(), 'set_clinic_facility_types', 'clinic', p_clinic_id::text, jsonb_build_object('facility_types', v_types));
  return jsonb_build_object('clinic_id', p_clinic_id, 'facility_types', v_types, 'primary_type', v_types[1]);
end;
$$;
revoke all on function public.platform_admin_set_clinic_facility_types(uuid,text[]) from public, anon;
grant execute on function public.platform_admin_set_clinic_facility_types(uuid,text[]) to authenticated;
