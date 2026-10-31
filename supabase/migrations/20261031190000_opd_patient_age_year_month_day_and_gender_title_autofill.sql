alter table public.patients
  add column if not exists age_months integer,
  add column if not exists age_days integer,
  add column if not exists age_recorded_on date;

alter table public.patients
  drop constraint if exists patients_age_months_check,
  drop constraint if exists patients_age_days_check;
alter table public.patients
  add constraint patients_age_months_check check (age_months is null or age_months between 0 and 11),
  add constraint patients_age_days_check check (age_days is null or age_days between 0 and 31);

create or replace function public.set_patient_age_details(
  p_clinic_id uuid,
  p_patient_id uuid,
  p_age_years integer default null,
  p_age_months integer default null,
  p_age_days integer default null,
  p_date_of_birth date default null,
  p_age_recorded_on date default current_date
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_patient public.patients%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.has_clinic_role(p_clinic_id, array['owner','admin','receptionist','doctor','nurse']) then
    raise exception 'Patient registration permission required';
  end if;
  if p_age_years is not null and p_age_years not between 0 and 125 then raise exception 'Age years must be between 0 and 125'; end if;
  if p_age_months is not null and p_age_months not between 0 and 11 then raise exception 'Age months must be between 0 and 11'; end if;
  if p_age_days is not null and p_age_days not between 0 and 31 then raise exception 'Age days must be between 0 and 31'; end if;
  if p_date_of_birth is not null and p_date_of_birth > coalesce(p_age_recorded_on,current_date) then raise exception 'Date of birth cannot be in the future'; end if;
  update public.patients
     set date_of_birth = coalesce(p_date_of_birth,date_of_birth),
         age_years = case when p_date_of_birth is not null then null else p_age_years end,
         age_months = case when p_date_of_birth is not null then null else p_age_months end,
         age_days = case when p_date_of_birth is not null then null else p_age_days end,
         age_recorded_on = case when p_date_of_birth is not null then null
           when p_age_years is not null or p_age_months is not null or p_age_days is not null
           then coalesce(p_age_recorded_on,current_date) else null end,
         updated_at = now()
   where id = p_patient_id and clinic_id = p_clinic_id returning * into v_patient;
  if v_patient.id is null then raise exception 'Patient not found in this clinic'; end if;
  return jsonb_build_object('patient_id',v_patient.id,'date_of_birth',v_patient.date_of_birth,
    'age_years',v_patient.age_years,'age_months',v_patient.age_months,
    'age_days',v_patient.age_days,'age_recorded_on',v_patient.age_recorded_on);
end;
$$;
revoke all on function public.set_patient_age_details(uuid,uuid,integer,integer,integer,date,date) from public, anon;
grant execute on function public.set_patient_age_details(uuid,uuid,integer,integer,integer,date,date) to authenticated;
notify pgrst, 'reload schema';
