-- Anaira Clinic v0.7.7: guarded platform-user lifecycle and audit read access.
-- Apply only to the dedicated Anaira Clinic Supabase project.
begin;

create or replace function public.platform_admin_list_users()
returns table(user_id uuid, email text, active boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;

  return query
    select pa.user_id, au.email::text, pa.active, pa.created_at
    from public.platform_admins as pa
    left join auth.users as au on au.id = pa.user_id
    order by pa.created_at desc;
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
  if not private.is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtext('anaira_platform_admin_lifecycle')::bigint);

  if p_user_id is null or p_active is null then
    raise exception 'User and target status are required' using errcode = '22004';
  end if;
  if p_user_id = v_actor and p_active = false then
    raise exception 'You cannot disable your own platform access' using errcode = '42501';
  end if;

  select pa.active into v_current_active
  from public.platform_admins as pa
  where pa.user_id = p_user_id
  for update;

  if not found then
    raise exception 'Platform administrator not found' using errcode = 'P0002';
  end if;

  if v_current_active = p_active then
    return;
  end if;

  if p_active = false then
    select count(*) into v_active_count
    from public.platform_admins as pa
    where pa.active = true;
    if v_active_count <= 1 then
      raise exception 'The last active platform administrator cannot be disabled' using errcode = '23514';
    end if;
  end if;

  update public.platform_admins
  set active = p_active
  where user_id = p_user_id;

  select au.email::text into v_email from auth.users as au where au.id = p_user_id;
  insert into public.platform_audit_logs(actor_user_id, action, entity_type, entity_id, details)
  values (
    v_actor,
    case when p_active then 'platform_admin_enabled' else 'platform_admin_disabled' end,
    'platform_admin',
    p_user_id::text,
    jsonb_build_object('email', v_email, 'active', p_active)
  );
end;
$$;

revoke all on function public.platform_admin_set_user_active(uuid, boolean) from public, anon;
grant execute on function public.platform_admin_set_user_active(uuid, boolean) to authenticated;

commit;
