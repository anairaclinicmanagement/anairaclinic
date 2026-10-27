-- Owners/admins must always be able to manage the staff directory, even if the optional staff module is not entitled.
-- Other clinic roles continue to require the staff module entitlement and role-specific policy.
drop policy if exists staff_profiles_module_entitlement on public.staff_profiles;
create policy staff_profiles_module_entitlement on public.staff_profiles as restrictive for all to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin']) or clinic_module_access(clinic_id,'staff'))
with check (private.has_clinic_role(clinic_id,array['owner','admin']) or clinic_module_access(clinic_id,'staff'));
