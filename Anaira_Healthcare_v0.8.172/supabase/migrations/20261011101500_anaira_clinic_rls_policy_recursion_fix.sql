-- Fixes recursive RLS evaluation by routing role lookups through a narrowly scoped private helper.
create or replace function private.has_clinic_role(p_clinic_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.clinic_members cm
    where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid())
      and cm.active=true and cm.role=any(p_roles)
  );
$$;
revoke all on function private.has_clinic_role(uuid,text[]) from public,anon;
grant execute on function private.has_clinic_role(uuid,text[]) to authenticated;
drop policy if exists clinics_update_owner on public.clinics;
create policy clinics_update_owner on public.clinics for update to authenticated
using(private.has_clinic_role(id,array['owner','admin']))
with check(private.has_clinic_role(id,array['owner','admin']));
drop policy if exists clinic_members_select_self_or_admin on public.clinic_members;
create policy clinic_members_select_self_or_admin on public.clinic_members for select to authenticated
using(user_id=(select auth.uid()) or private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_settings_insert_admin on public.clinic_settings;
create policy clinic_settings_insert_admin on public.clinic_settings for insert to authenticated
with check(private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_settings_update_admin on public.clinic_settings;
create policy clinic_settings_update_admin on public.clinic_settings for update to authenticated
using(private.has_clinic_role(clinic_id,array['owner','admin']))
with check(private.has_clinic_role(clinic_id,array['owner','admin']));
