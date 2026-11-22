-- Clinic-scoped staff login and least-privilege patient lookup for pharmacy/lab worklists.
-- Auth accounts are created only by the authenticated clinic-create-staff Edge Function.
create or replace function public.clinic_patient_directory(p_clinic_id uuid)
returns table(id uuid, clinic_id uuid, uhid text, first_name text, middle_name text, last_name text, phone text, gender text, date_of_birth date, created_at timestamptz)
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician']) then raise exception 'Patient directory access denied'; end if;
 return query select p.id,p.clinic_id,p.uhid,p.first_name,p.middle_name,p.last_name,p.phone,p.gender,p.date_of_birth,p.created_at
 from public.patients p where p.clinic_id=p_clinic_id and p.archived_at is null order by p.first_name,p.last_name limit 1000;
end $$;
revoke all on function public.clinic_patient_directory(uuid) from public,anon;
grant execute on function public.clinic_patient_directory(uuid) to authenticated;

-- Let every staff account read only its own staff profile. Existing owner/admin and module policies remain in force.
drop policy if exists staff_profiles_select_self on public.staff_profiles;
create policy staff_profiles_select_self on public.staff_profiles for select to authenticated
using (user_id=(select auth.uid()));
