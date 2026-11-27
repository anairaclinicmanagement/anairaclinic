-- Doctor directory profiles may be created before an authentication account exists.
-- Only clinic owners/admins can create, edit, or remove staff/doctor profiles.
drop policy if exists staff_profiles_owner_admin_insert on public.staff_profiles;
create policy staff_profiles_owner_admin_insert on public.staff_profiles as restrictive for insert to authenticated
with check (private.has_clinic_role(clinic_id, array['owner','admin']));

drop policy if exists staff_profiles_owner_admin_update on public.staff_profiles;
create policy staff_profiles_owner_admin_update on public.staff_profiles as restrictive for update to authenticated
using (private.has_clinic_role(clinic_id, array['owner','admin']))
with check (private.has_clinic_role(clinic_id, array['owner','admin']));

drop policy if exists staff_profiles_owner_admin_delete on public.staff_profiles;
create policy staff_profiles_owner_admin_delete on public.staff_profiles as restrictive for delete to authenticated
using (private.has_clinic_role(clinic_id, array['owner','admin']));
