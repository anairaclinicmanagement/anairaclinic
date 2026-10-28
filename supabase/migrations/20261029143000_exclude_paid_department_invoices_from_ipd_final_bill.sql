-- Prevent already-paid department invoices from being charged again on a later final IPD bill.
-- Existing paid invoices remain in the original department register.
do $$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='finalize_ipd_bill'
  order by p.oid desc limit 1;
  if v_def is null then raise exception 'finalize_ipd_bill function not found'; end if;
  if position('coalesce(i.paid_amount,0) < i.total_amount' in v_def)=0 then
    if position('and i.consolidated_into_invoice_id is null and i.status not in' in v_def)=0 then
      raise exception 'Expected final IPD invoice source filter not found; no changes made';
    end if;
    v_def := replace(v_def,
      'and i.consolidated_into_invoice_id is null and i.status not in',
      'and i.consolidated_into_invoice_id is null and coalesce(i.paid_amount,0) < i.total_amount and i.status not in');
    execute v_def;
  end if;
end $$;
