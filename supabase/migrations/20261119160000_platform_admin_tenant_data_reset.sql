-- Super Admin selective tenant-data reset. No clinic, subscription, membership,
-- module configuration, platform-admin, or audit tables are included.
create or replace function public.platform_admin_preview_clinic_data_reset(
  p_clinic_id uuid, p_categories text[]
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_category text; v_table record; v_count bigint; v_counts jsonb := '{}'::jsonb;
begin
  if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
  if p_clinic_id is null or coalesce(cardinality(p_categories),0)=0 then raise exception 'Clinic and categories are required'; end if;
  if exists(select 1 from unnest(p_categories) x where x not in ('patients','clinical','billing','diagnostics','inpatient','pharmacy','inventory','operations')) then raise exception 'Unsupported data category'; end if;
  foreach v_category in array p_categories loop
    v_count := 0;
    for v_table in
      select n.nspname, c.relname from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid=c.relnamespace
      join pg_catalog.pg_attribute a on a.attrelid=c.oid and a.attname='clinic_id' and not a.attisdropped
      where n.nspname='public' and c.relkind='r'
        and case v_category
          when 'patients' then c.relname in ('patients','appointments')
          when 'clinical' then c.relname in ('consultations','clinical_notes','medical_records','vitals','prescriptions','prescription_items','patient_documents','referrals','diagnoses')
          when 'billing' then c.relname in ('invoices','invoice_items','payments','refunds','credit_notes','billing_entries')
          when 'diagnostics' then c.relname in ('lab_orders','lab_order_items','lab_results','lab_tests','radiology_orders','radiology_results','radiology_reports')
          when 'inpatient' then c.relname in ('admissions','ipd_charges','ipd_notes','nursing_records','operation_theatre_cases','emergency_visits','bed_allocations','discharge_summaries')
          when 'pharmacy' then c.relname in ('pharmacy_sales','pharmacy_sale_items','medicine_batches','medicine_stock','stock_movements','dispensations')
          when 'inventory' then c.relname in ('inventory_batches','inventory_items','purchase_orders','purchase_order_items','goods_receipts','suppliers','procurement_requests')
          when 'operations' then c.relname in ('ambulance_trips','ambulance_dispatches','assets','asset_maintenance','maintenance_requests','procurement_requests')
          else false end
      order by (select count(*) from pg_catalog.pg_constraint fk where fk.contype='f' and fk.conrelid=c.oid) desc, c.relname
    loop
      execute format('select count(*) from %I.%I where clinic_id = $1',v_table.nspname,v_table.relname) into v_count using p_clinic_id;
      v_counts := jsonb_set(v_counts,array[v_category],to_jsonb(coalesce((v_counts->>v_category)::bigint,0)+v_count),true);
    end loop;
    if not (v_counts ? v_category) then v_counts:=jsonb_set(v_counts,array[v_category],'0'::jsonb,true); end if;
  end loop;
  return jsonb_build_object('clinic_id',p_clinic_id,'counts',v_counts,'preview_only',true);
end; $$;
revoke all on function public.platform_admin_preview_clinic_data_reset(uuid,text[]) from public,anon;
grant execute on function public.platform_admin_preview_clinic_data_reset(uuid,text[]) to authenticated;

create or replace function public.platform_admin_reset_clinic_data(
  p_clinic_id uuid, p_categories text[], p_confirmation text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_category text; v_table record; v_deleted bigint; v_total bigint:=0; v_clinic_name text;
begin
  if not private.is_platform_admin() then raise exception 'Platform super-admin permission required'; end if;
  if p_clinic_id is null or coalesce(cardinality(p_categories),0)=0 then raise exception 'Clinic and categories are required'; end if;
  if exists(select 1 from unnest(p_categories) x where x not in ('patients','clinical','billing','diagnostics','inpatient','pharmacy','inventory','operations')) then raise exception 'Unsupported data category'; end if;
  select name into v_clinic_name from public.clinics where id=p_clinic_id for update;
  if v_clinic_name is null or p_confirmation is distinct from v_clinic_name then raise exception 'Exact clinic name confirmation failed'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_clinic_id::text));
  foreach v_category in array p_categories loop
    for v_table in
      select n.nspname, c.relname from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid=c.relnamespace
      join pg_catalog.pg_attribute a on a.attrelid=c.oid and a.attname='clinic_id' and not a.attisdropped
      where n.nspname='public' and c.relkind='r'
        and case v_category
          when 'patients' then c.relname in ('patients','appointments')
          when 'clinical' then c.relname in ('consultations','clinical_notes','medical_records','vitals','prescriptions','prescription_items','patient_documents','referrals','diagnoses')
          when 'billing' then c.relname in ('invoices','invoice_items','payments','refunds','credit_notes','billing_entries')
          when 'diagnostics' then c.relname in ('lab_orders','lab_order_items','lab_results','lab_tests','radiology_orders','radiology_results','radiology_reports')
          when 'inpatient' then c.relname in ('admissions','ipd_charges','ipd_notes','nursing_records','operation_theatre_cases','emergency_visits','bed_allocations','discharge_summaries')
          when 'pharmacy' then c.relname in ('pharmacy_sales','pharmacy_sale_items','medicine_batches','medicine_stock','stock_movements','dispensations')
          when 'inventory' then c.relname in ('inventory_batches','inventory_items','purchase_orders','purchase_order_items','goods_receipts','suppliers','procurement_requests')
          when 'operations' then c.relname in ('ambulance_trips','ambulance_dispatches','assets','asset_maintenance','maintenance_requests','procurement_requests')
          else false end
      order by (select count(*) from pg_catalog.pg_constraint fk where fk.contype='f' and fk.conrelid=c.oid) desc, c.relname
    loop
      execute format('delete from %I.%I where clinic_id = $1',v_table.nspname,v_table.relname) using p_clinic_id;
      get diagnostics v_deleted = row_count;
      v_total:=v_total+v_deleted;
    end loop;
  end loop;
  if to_regclass('public.platform_audit_logs') is not null then
    insert into public.platform_audit_logs(actor_user_id,action,entity_type,entity_id,details,occurred_at)
    values(auth.uid(),'platform_admin_tenant_data_reset','clinic',p_clinic_id::text,
      jsonb_build_object('clinic_name',v_clinic_name,'categories',p_categories,'deleted_rows',v_total),now());
  end if;
  return jsonb_build_object('clinic_id',p_clinic_id,'deleted_rows',v_total,'categories',p_categories,'audit_retained',true);
end; $$;
revoke all on function public.platform_admin_reset_clinic_data(uuid,text[],text) from public,anon;
grant execute on function public.platform_admin_reset_clinic_data(uuid,text[],text) to authenticated;
