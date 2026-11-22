-- Anaira Clinic v0.8.26: Super Admin clinic profile edit + complete registry fields.
-- Additive and data-preserving. Apply this migration before using the Edit clinic action.

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
   'clinics',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',c.id,'name',c.name,'clinic_type',c.clinic_type,'email',c.email,'phone',c.phone,
      'facility_model',c.facility_model,'specialties',c.specialties,'enabled_modules',c.enabled_modules,
      'clinic_profile',c.clinic_profile,'platform_status',c.platform_status,'created_at',c.created_at,
      'member_count',(select count(*) from public.clinic_members cm where cm.clinic_id=c.id and cm.active=true),
      'subscription',(select jsonb_build_object('status',s.status,'billing_cycle',s.billing_cycle,'starts_at',s.starts_at,'ends_at',s.ends_at,'plan_name',p.name,'plan_id',p.id) from public.clinic_subscriptions s left join public.clinic_plans p on p.id=s.plan_id where s.clinic_id=c.id)
   ) order by c.created_at desc),'[]'::jsonb) from public.clinics c)
 ) into v_result;
 return v_result;
end $$;
revoke all on function public.platform_admin_dashboard() from public,anon;
grant execute on function public.platform_admin_dashboard() to authenticated;

create or replace function public.platform_admin_update_clinic_profile(
 p_clinic_id uuid,
 p_name text,
 p_clinic_type text,
 p_email text,
 p_phone text default null,
 p_facility_model text default 'single_site',
 p_specialties text[] default array['general_medicine']::text[],
 p_enabled_modules text[] default array['patients','appointments','consultation','prescriptions','billing']::text[]
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_specialties text[]:=coalesce(p_specialties,array[]::text[]); v_modules text[]:=coalesce(p_enabled_modules,array[]::text[]);
begin
 if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
 if coalesce(length(trim(p_name)),0)<2 or length(trim(p_name))>160 then raise exception 'Clinic name must contain 2 to 160 characters'; end if;
 if coalesce(trim(p_email),'') !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Valid clinic email is required'; end if;
 if p_clinic_type not in ('general_opd','general_medicine','dental','orthodontics','oral_surgery','periodontics','prosthodontics','eye','ophthalmology','optometry','skin','dermatology','cosmetology','pediatrics','neonatology','gynecology','obstetrics','fertility','orthopedic','sports_medicine','physiotherapy','neurology','cardiology','diabetology','endocrinology','gastroenterology','pulmonology','nephrology','urology','ENT','ent','psychiatry','psychology','oncology','rheumatology','geriatrics','pain_management','ayurveda','homeopathy','unani','siddha','naturopathy','diagnostic_lab','radiology_centre','pathology_lab','imaging_centre','dialysis_centre','vaccination_centre','urgent_care','polyclinic','nursing_home','maternity_home','day_care_centre','rehabilitation_centre','fertility_centre','eye_hospital','dental_hospital','hospital','multi_specialty_hospital','super_specialty_hospital','other') then raise exception 'Unsupported clinic type'; end if;
 if p_facility_model not in ('single_site','multi_branch_clinic','multi_clinic_network','hospital','multi_hospital_network','polyclinic','diagnostic_centre') then raise exception 'Unsupported facility model'; end if;
 if cardinality(v_specialties)=0 then raise exception 'Select at least one specialty'; end if;
 if cardinality(v_modules)=0 then raise exception 'Enable at least one module'; end if;
 update public.clinics set name=trim(p_name),clinic_type=p_clinic_type,email=lower(trim(p_email)),
   phone=nullif(trim(coalesce(p_phone,'')),''),facility_model=p_facility_model,
   specialties=v_specialties,enabled_modules=v_modules,
   clinic_profile=coalesce(clinic_profile,'{}'::jsonb)||jsonb_build_object('profile_updated_at',now(),'profile_updated_by',v_user),
   updated_at=now()
 where id=p_clinic_id;
 if not found then raise exception 'Clinic not found'; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'platform_admin_update_clinic_profile','clinic',p_clinic_id::text,
 jsonb_build_object('name',trim(p_name),'clinic_type',p_clinic_type,'facility_model',p_facility_model,'specialties',v_specialties,'enabled_modules',v_modules));
 insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(v_user,'update_clinic_profile','clinic',p_clinic_id::text,jsonb_build_object('name',trim(p_name),'clinic_type',p_clinic_type,'facility_model',p_facility_model));
 return jsonb_build_object('clinic_id',p_clinic_id,'updated',true);
end $$;
revoke all on function public.platform_admin_update_clinic_profile(uuid,text,text,text,text,text,text[],text[]) from public,anon;
grant execute on function public.platform_admin_update_clinic_profile(uuid,text,text,text,text,text,text[],text[]) to authenticated;
