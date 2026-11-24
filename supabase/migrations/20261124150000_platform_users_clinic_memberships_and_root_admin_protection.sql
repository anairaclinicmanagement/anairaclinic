-- Expand Platform Users to show hospital-wise memberships and protect root owner.
begin;

drop function if exists public.platform_admin_list_users();
create function public.platform_admin_list_users()
returns table(
  user_id uuid,
  email text,
  active boolean,
  created_at timestamptz,
  user_type text,
  role text,
  clinic_id uuid,
  clinic_name text,
  is_protected boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() ->> 'aal') is distinct from 'aal2' then
    raise exception 'MFA verification required' using errcode = '42501';
  end if;
  if not private.is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;

  return query
    select pa.user_id, au.email::text, pa.active, pa.created_at,
           'platform_admin'::text, 'super_admin'::text, null::uuid, null::text,
           (pa.user_id = '198137fa-8682-432f-8b7a-e99aebe89ddd'::uuid)
    from public.platform_admins pa
    left join auth.users au on au.id = pa.user_id
    union all
    select cm.user_id, au.email::text, cm.active, cm.created_at,
           'clinic_user'::text, cm.role, cm.clinic_id, c.name,
           false
    from public.clinic_members cm
    left join auth.users au on au.id = cm.user_id
    left join public.clinics c on c.id = cm.clinic_id
    order by 2, 7 nulls first, 6;
end;
$$;
revoke all on function public.platform_admin_list_users() from public, anon;
grant execute on function public.platform_admin_list_users() to authenticated;

create or replace function public.platform_admin_set_user_active(p_user_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_active boolean;
  v_active_count integer;
  v_actor uuid := auth.uid();
  v_email text;
begin
  if (auth.jwt() ->> 'aal') is distinct from 'aal2' then
    raise exception 'MFA verification required' using errcode = '42501';
  end if;
  if not private.is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtext('anaira_platform_admin_lifecycle')::bigint);

  if p_user_id = '198137fa-8682-432f-8b7a-e99aebe89ddd'::uuid then
    raise exception 'Root Super Admin is protected and cannot be disabled' using errcode = '42501';
  end if;
  if p_user_id is null or p_active is null then
    raise exception 'User and target status are required' using errcode = '22004';
  end if;
  if p_user_id = v_actor and p_active = false then
    raise exception 'You cannot disable your own platform access' using errcode = '42501';
  end if;

  select pa.active into v_current_active
  from public.platform_admins pa
  where pa.user_id = p_user_id
  for update;
  if not found then
    raise exception 'Platform administrator not found' using errcode = 'P0002';
  end if;
  if v_current_active = p_active then return; end if;

  if p_active = false then
    select count(*) into v_active_count from public.platform_admins pa where pa.active = true;
    if v_active_count <= 1 then
      raise exception 'The last active platform administrator cannot be disabled' using errcode = '23514';
    end if;
  end if;

  update public.platform_admins set active = p_active where user_id = p_user_id;
  select au.email::text into v_email from auth.users au where au.id = p_user_id;
  insert into public.platform_audit_logs(actor_user_id, action, entity_type, entity_id, details)
  values (v_actor, case when p_active then 'platform_admin_enabled' else 'platform_admin_disabled' end,
          'platform_admin', p_user_id::text, jsonb_build_object('email',v_email,'active',p_active));
end;
$$;
revoke all on function public.platform_admin_set_user_active(uuid, boolean) from public, anon;
grant execute on function public.platform_admin_set_user_active(uuid, boolean) to authenticated;

create or replace function public.platform_admin_set_clinic_member_active(p_member_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_clinic_id uuid;
  v_email text;
  v_clinic_name text;
begin
  if (auth.jwt() ->> 'aal') is distinct from 'aal2' then
    raise exception 'MFA verification required' using errcode = '42501';
  end if;
  if not private.is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;
  if p_member_id is null or p_active is null then
    raise exception 'Membership and target status are required' using errcode = '22004';
  end if;

  select cm.user_id, cm.clinic_id into v_user_id, v_clinic_id
  from public.clinic_members cm where cm.id = p_member_id for update;
  if not found then raise exception 'Clinic membership not found' using errcode = 'P0002'; end if;

  update public.clinic_members set active = p_active where id = p_member_id;
  select au.email::text into v_email from auth.users au where au.id = v_user_id;
  select c.name into v_clinic_name from public.clinics c where c.id = v_clinic_id;

  insert into public.platform_audit_logs(actor_user_id, action, entity_type, entity_id, details)
  values (auth.uid(), case when p_active then 'clinic_member_enabled_by_platform' else 'clinic_member_disabled_by_platform' end,
          'clinic_member', p_member_id::text,
          jsonb_build_object('user_id',v_user_id,'email',v_email,'clinic_id',v_clinic_id,'clinic_name',v_clinic_name,'active',p_active));
end;
$$;
revoke all on function public.platform_admin_set_clinic_member_active(uuid, boolean) from public, anon;
grant execute on function public.platform_admin_set_clinic_member_active(uuid, boolean) to authenticated;

commit;
