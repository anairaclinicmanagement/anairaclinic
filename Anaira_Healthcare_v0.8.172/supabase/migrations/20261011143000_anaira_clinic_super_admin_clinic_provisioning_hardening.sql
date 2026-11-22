-- Platform-admin provisioning RPC. Applied to dedicated Anaira Clinic project.
-- Existing owner must already have an Auth account; no password or service key is handled in the browser.
create or replace function public.platform_admin_create_clinic(
  p_name text,
  p_clinic_type text,
  p_owner_email text,
  p_phone text default null
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_owner uuid; v_admin uuid:=auth.uid(); v_clinic uuid; v_plan uuid;
begin
  if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
  if coalesce(length(trim(p_name)),0)<2 or length(trim(p_name))>160 then raise exception 'Clinic name must contain 2 to 160 characters'; end if;
  if coalesce(trim(p_owner_email),'')='' then raise exception 'Owner email is required'; end if;
  if p_clinic_type not in ('general_opd','dental','eye','skin','pediatrics','gynecology','orthopedic','ayurveda','homeopathy','physiotherapy','diagnostic_lab','polyclinic','hospital','other') then raise exception 'Unsupported clinic type'; end if;
  select u.id into v_owner from auth.users u where lower(u.email)=lower(trim(p_owner_email)) limit 1;
  if v_owner is null then raise exception 'No Supabase Auth user found for this owner email. Ask the owner to create an account first.'; end if;
  insert into public.clinics(name,clinic_type,email,phone,created_by,platform_status)
  values(trim(p_name),p_clinic_type,lower(trim(p_owner_email)),nullif(trim(coalesce(p_phone,'')),''),v_admin,'active') returning id into v_clinic;
  insert into public.clinic_members(clinic_id,user_id,role,display_name,active) values(v_clinic,v_owner,'owner',trim(p_owner_email),true);
  insert into public.clinic_branches(clinic_id,name,code,is_primary) values(v_clinic,'Main Branch','MAIN',true);
  insert into public.clinic_settings(clinic_id,settings,updated_by) values(v_clinic,'{}'::jsonb,v_admin);
  select id into v_plan from public.clinic_plans where code='starter' and active=true limit 1;
  insert into public.clinic_subscriptions(clinic_id,plan_id,status,billing_cycle,starts_at,trial_ends_at,metadata)
  values(v_clinic,v_plan,'trial','monthly',now(),now()+interval '14 days',jsonb_build_object('source','platform_admin'));
  insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details)
  values(v_admin,'create_clinic','clinic',v_clinic::text,jsonb_build_object('name',trim(p_name),'owner_email',lower(trim(p_owner_email))));
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
  values(v_clinic,v_admin,'platform_created_clinic','clinic',v_clinic::text,jsonb_build_object('owner_email',lower(trim(p_owner_email))));
  return jsonb_build_object('clinic_id',v_clinic,'owner_user_id',v_owner,'status','active');
end;
$$;
revoke all on function public.platform_admin_create_clinic(text,text,text,text) from public,anon;
grant execute on function public.platform_admin_create_clinic(text,text,text,text) to authenticated;
