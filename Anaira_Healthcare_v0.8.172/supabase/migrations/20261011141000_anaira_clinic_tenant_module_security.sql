-- v0.6.1: platform suspension, subscription and feature entitlements enforced by RLS.
-- Additive, tenant-scoped, and does not remove existing clinical data.
create unique index if not exists patients_clinic_id_id_uq on public.patients(clinic_id,id);
create unique index if not exists blood_components_clinic_id_id_uq on public.blood_components(clinic_id,id);

do $$ declare r record; begin
 for r in select * from (values
 ('patient_consents','patient_consents_patient_same_clinic_fk'),('patient_documents','patient_documents_patient_same_clinic_fk'),('radiology_orders','radiology_orders_patient_same_clinic_fk'),('operation_theatre_cases','operation_theatre_cases_patient_same_clinic_fk'),('emergency_visits','emergency_visits_patient_same_clinic_fk'),('blood_issues','blood_issues_patient_same_clinic_fk'),('diet_orders','diet_orders_patient_same_clinic_fk'),('teleconsultations','teleconsultations_patient_same_clinic_fk'),('referrals','referrals_patient_same_clinic_fk'),('clinical_quality_events','clinical_quality_events_patient_same_clinic_fk'),('patient_feedback','patient_feedback_patient_same_clinic_fk')
 ) as x(tbl,cn) loop
  if not exists(select 1 from pg_constraint where conname=r.cn and conrelid=('public.'||r.tbl)::regclass) then execute format('alter table public.%I add constraint %I foreign key(clinic_id,patient_id) references public.patients(clinic_id,id) not valid',r.tbl,r.cn); end if;
 end loop;
 if not exists(select 1 from pg_constraint where conname='blood_issues_component_same_clinic_fk' and conrelid='public.blood_issues'::regclass) then alter table public.blood_issues add constraint blood_issues_component_same_clinic_fk foreign key(clinic_id,component_id) references public.blood_components(clinic_id,id) not valid; end if;
end $$;

create or replace function private.is_clinic_member(p_clinic_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.clinic_members cm join public.clinics c on c.id=cm.clinic_id left join public.clinic_subscriptions s on s.clinic_id=c.id where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true and c.platform_status='active' and (s.id is null or (s.status in ('trial','active') and (s.ends_at is null or s.ends_at>now()))));
$$;
create or replace function private.has_clinic_role(p_clinic_id uuid,p_roles text[]) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.clinic_members cm join public.clinics c on c.id=cm.clinic_id left join public.clinic_subscriptions s on s.clinic_id=c.id where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true and cm.role=any(p_roles) and c.platform_status='active' and (s.id is null or (s.status in ('trial','active') and (s.ends_at is null or s.ends_at>now()))));
$$;
revoke all on function private.is_clinic_member(uuid) from public,anon; grant execute on function private.is_clinic_member(uuid) to authenticated;
revoke all on function private.has_clinic_role(uuid,text[]) from public,anon; grant execute on function private.has_clinic_role(uuid,text[]) to authenticated;

create or replace function public.clinic_module_access(p_clinic_id uuid,p_module_code text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_modules text[]; v_override boolean; v_clinic_status text; v_sub_status text; v_ends timestamptz; v_flag text; v_flag_enabled boolean;
begin
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']) then return false; end if;
 select c.platform_status,s.status,s.ends_at,p.enabled_modules into v_clinic_status,v_sub_status,v_ends,v_modules from public.clinics c left join public.clinic_subscriptions s on s.clinic_id=c.id left join public.clinic_plans p on p.id=s.plan_id where c.id=p_clinic_id;
 if v_clinic_status is distinct from 'active' then return false; end if;
 if v_sub_status is null then v_sub_status:='trial'; v_modules:=array['patients','appointments','consultation','prescriptions','billing']::text[]; end if;
 if v_sub_status not in ('trial','active') or (v_ends is not null and v_ends<now()) then return false; end if;
 select enabled into v_override from public.clinic_module_overrides where clinic_id=p_clinic_id and module_code=lower(p_module_code) and (expires_at is null or expires_at>now()) limit 1;
 if v_override is false then return false; end if;
 v_flag:=case lower(p_module_code) when 'radiology' then 'radiology' when 'operation_theatre' then 'operation_theatre' when 'emergency' then 'emergency' when 'blood_bank' then 'blood_bank' when 'cssd' then 'cssd' when 'diet' then 'diet' when 'ambulance' then 'ambulance' when 'procurement' then 'procurement' when 'asset_management' then 'asset_management' when 'telemedicine' then 'telemedicine' when 'referrals' then 'referrals' when 'clinical_quality' then 'clinical_quality' when 'patient_portal' then 'patient_portal' when 'offline_sync' then 'offline_sync' else null end;
 if v_flag is not null then select enabled into v_flag_enabled from public.platform_feature_flags where code=v_flag; if coalesce(v_flag_enabled,false)=false then return false; end if; end if;
 if v_override is true then return true; end if; return coalesce(lower(p_module_code)=any(v_modules),false);
end $$;
revoke all on function public.clinic_module_access(uuid,text) from public,anon; grant execute on function public.clinic_module_access(uuid,text) to authenticated;

do $$ declare r record; begin
 for r in select * from (values
 ('patients','patients'),('appointments','appointments'),('clinic_branches','multi_branch'),('staff_profiles','staff'),('doctor_schedules','appointments'),('encounters','consultation'),('vitals','consultation'),('diagnoses','consultation'),('prescriptions','prescriptions'),('prescription_items','prescriptions'),('medications','pharmacy'),('inventory_batches','pharmacy'),('stock_movements','pharmacy'),('lab_tests','laboratory'),('lab_orders','laboratory'),('lab_order_items','laboratory'),('services','billing'),('invoices','billing'),('invoice_items','billing'),('payments','billing'),('expenses','billing'),('insurance_claims','insurance'),('rooms','ipd'),('admissions','ipd'),('nursing_records','ipd'),('procedures','consultation'),('sync_outbox','offline_sync'),('offline_mutations','offline_sync'),('patient_consents','patients'),('patient_documents','patients'),('radiology_orders','radiology'),('operation_theatre_cases','operation_theatre'),('emergency_visits','emergency'),('blood_donors','blood_bank'),('blood_components','blood_bank'),('blood_issues','blood_bank'),('sterilization_cycles','cssd'),('diet_orders','diet'),('ambulance_trips','ambulance'),('purchase_orders','procurement'),('purchase_order_items','procurement'),('clinic_assets','asset_management'),('maintenance_work_orders','asset_management'),('teleconsultations','telemedicine'),('referrals','referrals'),('clinical_quality_events','clinical_quality'),('patient_feedback','clinical_quality'),('staff_shifts','staff'),('staff_leave_requests','staff')
 ) as x(tbl,mod) loop
  execute format('drop policy if exists %I on public.%I',r.tbl||'_module_entitlement',r.tbl);
  execute format('create policy %I on public.%I as restrictive for all to authenticated using(public.clinic_module_access(clinic_id,%L)) with check(public.clinic_module_access(clinic_id,%L))',r.tbl||'_module_entitlement',r.tbl,r.mod,r.mod);
 end loop;
end $$;

-- Keep highly sensitive registers limited to clinical/authorised roles in addition to the module gate.
drop policy if exists patient_documents_tenant_select on public.patient_documents;
create policy patient_documents_tenant_select on public.patient_documents for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist']));
drop policy if exists patient_consents_tenant_select on public.patient_consents;
create policy patient_consents_tenant_select on public.patient_consents for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist']));
drop policy if exists clinical_quality_events_tenant_select on public.clinical_quality_events;
create policy clinical_quality_events_tenant_select on public.clinical_quality_events for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','staff']));
comment on function public.clinic_module_access(uuid,text) is 'Tenant entitlement gate for clinic status, subscription, plan modules, overrides and global feature flags.';
