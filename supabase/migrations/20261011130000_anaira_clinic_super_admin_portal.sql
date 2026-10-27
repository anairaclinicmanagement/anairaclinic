-- Anaira Clinic platform Super Admin console.
-- Initial platform-admin identity is provisioned by a separate trusted migration.
alter table public.clinics add column if not exists platform_status text not null default 'active' check(platform_status in ('active','suspended','pending'));

create or replace function private.is_platform_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.platform_admins pa where pa.user_id=(select auth.uid()) and pa.active=true);
$$;
revoke all on function private.is_platform_admin() from public,anon;
grant execute on function private.is_platform_admin() to authenticated;

create or replace function public.platform_admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 select jsonb_build_object(
   'clinic_count',(select count(*) from public.clinics),
   'active_clinics',(select count(*) from public.clinics where platform_status='active'),
   'suspended_clinics',(select count(*) from public.clinics where platform_status='suspended'),
   'patient_count',(select count(*) from public.patients),
   'staff_count',(select count(*) from public.clinic_members where active=true),
   'plans',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'price_monthly',p.price_monthly,'price_yearly',p.price_yearly,'max_branches',p.max_branches,'max_staff',p.max_staff,'active',p.active,'enabled_modules',p.enabled_modules) order by p.price_monthly),'[]'::jsonb) from public.clinic_plans p),
   'clinics',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'clinic_type',c.clinic_type,'platform_status',c.platform_status,'created_at',c.created_at,'member_count',(select count(*) from public.clinic_members cm where cm.clinic_id=c.id and cm.active=true),'subscription',(select jsonb_build_object('status',s.status,'billing_cycle',s.billing_cycle,'starts_at',s.starts_at,'ends_at',s.ends_at,'plan_name',p.name,'plan_id',p.id) from public.clinic_subscriptions s left join public.clinic_plans p on p.id=s.plan_id where s.clinic_id=c.id)) order by c.created_at desc),'[]'::jsonb) from public.clinics c)
 ) into v_result;
 return v_result;
end $$;
revoke all on function public.platform_admin_dashboard() from public,anon;
grant execute on function public.platform_admin_dashboard() to authenticated;

create or replace function public.platform_admin_set_clinic_status(p_clinic_id uuid,p_status text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if p_status not in ('active','suspended','pending') then raise exception 'Invalid clinic status'; end if;
 update public.clinics set platform_status=p_status,updated_at=now() where id=p_clinic_id;
 if not found then raise exception 'Clinic not found'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'platform_admin_set_status','clinic',p_clinic_id::text,jsonb_build_object('platform_status',p_status));
 return jsonb_build_object('clinic_id',p_clinic_id,'platform_status',p_status);
end $$;
revoke all on function public.platform_admin_set_clinic_status(uuid,text) from public,anon;
grant execute on function public.platform_admin_set_clinic_status(uuid,text) to authenticated;

create or replace function public.platform_admin_set_subscription(p_clinic_id uuid,p_plan_id uuid,p_status text,p_billing_cycle text default 'monthly',p_ends_at timestamptz default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if p_status not in ('trial','active','past_due','suspended','cancelled','expired') then raise exception 'Invalid subscription status'; end if;
 if p_billing_cycle not in ('monthly','yearly') then raise exception 'Invalid billing cycle'; end if;
 if not exists(select 1 from public.clinics where id=p_clinic_id) then raise exception 'Clinic not found'; end if;
 if p_plan_id is not null and not exists(select 1 from public.clinic_plans where id=p_plan_id and active=true) then raise exception 'Active plan not found'; end if;
 insert into public.clinic_subscriptions(clinic_id,plan_id,status,billing_cycle,starts_at,ends_at,updated_at) values(p_clinic_id,p_plan_id,p_status,p_billing_cycle,now(),p_ends_at,now())
 on conflict(clinic_id) do update set plan_id=excluded.plan_id,status=excluded.status,billing_cycle=excluded.billing_cycle,starts_at=case when public.clinic_subscriptions.status in ('cancelled','expired') and excluded.status in ('trial','active') then now() else public.clinic_subscriptions.starts_at end,ends_at=excluded.ends_at,updated_at=now() returning id into v_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'platform_admin_set_subscription','subscription',v_id::text,jsonb_build_object('plan_id',p_plan_id,'status',p_status,'billing_cycle',p_billing_cycle,'ends_at',p_ends_at));
 return jsonb_build_object('subscription_id',v_id,'clinic_id',p_clinic_id,'plan_id',p_plan_id,'status',p_status,'billing_cycle',p_billing_cycle,'ends_at',p_ends_at);
end $$;
revoke all on function public.platform_admin_set_subscription(uuid,uuid,text,text,timestamptz) from public,anon;
grant execute on function public.platform_admin_set_subscription(uuid,uuid,text,text,timestamptz) to authenticated;

create or replace function public.platform_admin_set_plan_active(p_plan_id uuid,p_active boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 update public.clinic_plans set active=p_active where id=p_plan_id;
 if not found then raise exception 'Plan not found'; end if;
 return jsonb_build_object('plan_id',p_plan_id,'active',p_active);
end $$;
revoke all on function public.platform_admin_set_plan_active(uuid,boolean) from public,anon;
grant execute on function public.platform_admin_set_plan_active(uuid,boolean) to authenticated;
