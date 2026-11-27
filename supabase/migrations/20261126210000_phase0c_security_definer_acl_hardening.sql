-- Anaira Healthcare Phase 0C security hardening.
-- Corrected to resolve live function OIDs/signatures from pg_proc at migration time.
-- This avoids relying on hand-copied argument signatures.
-- No table or business-row changes. Validate in non-production before production use.

begin;

do $$
declare
  r record;
  v_rpc text[] := array[
    'create_pharmacy_purchase_return_from_store',
    'dispense_pharmacy_sale_discounted_from_store',
    'dispense_pharmacy_sale_for_admission_from_store',
    'dispense_pharmacy_sale_from_store',
    'pharmacy_approve_store_stock_count',
    'pharmacy_decide_sales_return_to_store',
    'pharmacy_submit_store_stock_count',
    'receive_pharmacy_grn_to_store'
  ];
  v_trigger text[] := array[
    'pharmacy_assign_payment_shift',
    'pharmacy_assign_refund_shift',
    'pharmacy_sync_batch_quantity_to_main_store',
    'prevent_ipd_bed_double_allocation',
    'release_ipd_room_allocation_beds_on_admission_change',
    'validate_ipd_admission_package_scope'
  ];
  v_rpc_count integer := 0;
  v_trigger_count integer := 0;
begin
  for r in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef and p.proname = any(v_rpc)
  loop
    execute format('revoke execute on function %s from public, anon', r.oid::regprocedure);
    v_rpc_count := v_rpc_count + 1;
  end loop;

  for r in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and p.prorettype = 'trigger'::regtype
      and p.proname = any(v_trigger)
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.oid::regprocedure);
    v_trigger_count := v_trigger_count + 1;
  end loop;

  if v_rpc_count <> cardinality(v_rpc) then
    raise exception 'Expected % guarded pharmacy RPCs, found %; aborting ACL migration',
      cardinality(v_rpc), v_rpc_count;
  end if;
  if v_trigger_count <> cardinality(v_trigger) then
    raise exception 'Expected % trigger functions, found %; aborting ACL migration',
      cardinality(v_trigger), v_trigger_count;
  end if;
end $$;

alter function public.validate_ipd_admission_package_scope() set search_path = '';

commit;
