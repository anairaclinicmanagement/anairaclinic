-- Applied to the Anaira Clinic project after core RBAC.
create or replace function private.has_clinic_role(p_clinic_id uuid,p_roles text[]) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.clinic_members cm where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid()) and cm.active=true and cm.role=any(p_roles)); $$;
revoke all on function private.has_clinic_role(uuid,text[]) from public,anon;
grant execute on function private.has_clinic_role(uuid,text[]) to authenticated;
do $$ declare t text; r text[]; begin
foreach t in array array['clinic_branches','staff_profiles','doctor_schedules','patients','appointments','encounters','vitals','diagnoses','medications','prescriptions','prescription_items','inventory_batches','lab_tests','lab_orders','lab_order_items','services','invoices','invoice_items','payments','insurance_claims','rooms','admissions','clinic_settings','audit_logs','sync_outbox','expenses','stock_movements','procedures','nursing_records','offline_mutations'] loop
r:=array['owner','admin'];
if t in ('patients','appointments') then r:=array['owner','admin','doctor','receptionist','nurse']; end if;
if t in ('encounters','vitals','diagnoses') then r:=array['owner','admin','doctor','nurse']; end if;
if t in ('medications','prescriptions','prescription_items') then r:=array['owner','admin','doctor','pharmacist']; end if;
if t in ('inventory_batches','stock_movements') then r:=array['owner','admin','pharmacist']; end if;
if t in ('lab_tests','lab_orders','lab_order_items') then r:=array['owner','admin','doctor','lab_technician']; end if;
if t in ('services','invoices','invoice_items','payments','expenses','insurance_claims') then r:=array['owner','admin','accountant','receptionist']; end if;
if t in ('staff_profiles','doctor_schedules') then r:=array['owner','admin','doctor','receptionist']; end if;
if t in ('rooms','admissions','nursing_records') then r:=array['owner','admin','doctor','nurse']; end if;
if t in ('clinic_branches','clinic_settings','audit_logs') then r:=array['owner','admin']; end if;
if t in ('sync_outbox','offline_mutations') then r:=array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','accountant','staff']; end if;
execute format('drop policy if exists %I on public.%I',t||'_select_role',t);
execute format('create policy %I on public.%I for select to authenticated using(private.has_clinic_role(clinic_id,%L::text[]))',t||'_select_role',t,r);
end loop; end $$;
drop policy if exists clinic_subscriptions_select_admin on public.clinic_subscriptions;
create policy clinic_subscriptions_select_admin on public.clinic_subscriptions for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists clinic_module_overrides_select_admin on public.clinic_module_overrides;
create policy clinic_module_overrides_select_admin on public.clinic_module_overrides for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin']));
