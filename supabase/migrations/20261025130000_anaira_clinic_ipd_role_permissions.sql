-- Tighten IPD table permissions to explicit clinic roles.
-- Admission creation/discharge continues through the audited SECURITY DEFINER RPCs.
drop policy if exists rooms_select_member on public.rooms;
drop policy if exists rooms_insert_member on public.rooms;
drop policy if exists rooms_update_member on public.rooms;
drop policy if exists rooms_delete_member on public.rooms;
create policy rooms_select_ipd_roles on public.rooms for select to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist']));
create policy rooms_insert_admin on public.rooms for insert to authenticated
 with check (private.has_clinic_role(clinic_id,array['owner','admin']));
create policy rooms_update_admin on public.rooms for update to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin']))
 with check (private.has_clinic_role(clinic_id,array['owner','admin']));
create policy rooms_delete_admin on public.rooms for delete to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin']));

drop policy if exists admissions_select_member on public.admissions;
drop policy if exists admissions_insert_member on public.admissions;
drop policy if exists admissions_update_member on public.admissions;
drop policy if exists admissions_delete_member on public.admissions;
create policy admissions_select_ipd_roles on public.admissions for select to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant']));
-- New admissions must be created by create_clinic_admission(), which checks capacity and writes an audit event.
create policy admissions_insert_rpc_only on public.admissions for insert to authenticated with check (false);
create policy admissions_update_clinical_roles on public.admissions for update to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse']))
 with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse']));
create policy admissions_delete_admin on public.admissions for delete to authenticated
 using (private.has_clinic_role(clinic_id,array['owner','admin']));
