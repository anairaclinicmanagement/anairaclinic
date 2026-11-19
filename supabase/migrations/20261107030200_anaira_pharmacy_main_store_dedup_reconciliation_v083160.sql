-- Canonicalize one Main Pharmacy store per clinic. Older tenant data already used
-- MAIN-PHARMACY; the v0.8.160 bootstrap introduced MAIN, so reconcile without double counting.
do $$
declare c record; oldid uuid; canonid uuid; b record; other_qty numeric; target numeric;
begin
 for c in select distinct clinic_id from public.pharmacy_stores loop
  select id into canonid from public.pharmacy_stores where clinic_id=c.clinic_id and store_code='MAIN-PHARMACY' and active limit 1;
  select id into oldid from public.pharmacy_stores where clinic_id=c.clinic_id and store_code='MAIN' limit 1;
  if canonid is null then
   if oldid is not null then update public.pharmacy_stores set store_code='MAIN-PHARMACY' where id=oldid; canonid:=oldid; end if;
  elsif oldid is not null then
   update public.pharmacy_dispense_allocations set store_id=canonid where clinic_id=c.clinic_id and store_id=oldid;
   update public.pharmacy_sales_returns set store_id=canonid where clinic_id=c.clinic_id and store_id=oldid;
   for b in select id,quantity_on_hand,medication_id from public.inventory_batches where clinic_id=c.clinic_id loop
    select coalesce(sum(quantity),0) into other_qty from public.pharmacy_store_stock where clinic_id=c.clinic_id and batch_id=b.id and store_id not in (oldid,canonid);
    target:=greatest(b.quantity_on_hand-other_qty,0);
    insert into public.pharmacy_store_stock(clinic_id,store_id,batch_id,medication_id,quantity) values(c.clinic_id,canonid,b.id,b.medication_id,target)
    on conflict(clinic_id,store_id,batch_id) do update set quantity=excluded.quantity;
    update public.pharmacy_store_stock set quantity=0 where clinic_id=c.clinic_id and store_id=oldid and batch_id=b.id;
   end loop;
   update public.pharmacy_stores set active=false where id=oldid;
  end if;
 end loop;
end $$;
do $$ declare d text; begin
 d:=pg_get_functiondef('public.dispense_pharmacy_sale_from_store(uuid,uuid,jsonb,uuid,text,boolean,uuid)'::regprocedure); d:=replace(d,'''MAIN''','''MAIN-PHARMACY'''); execute d;
 d:=pg_get_functiondef('public.receive_pharmacy_grn_to_store(uuid,uuid,jsonb,uuid,text,date,numeric,text,uuid)'::regprocedure); d:=replace(d,'''MAIN''','''MAIN-PHARMACY'''); execute d;
 d:=pg_get_functiondef('public.pharmacy_decide_sales_return_to_store(uuid,uuid,boolean)'::regprocedure); d:=replace(d,'''MAIN''','''MAIN-PHARMACY'''); execute d;
 d:=pg_get_functiondef('public.create_pharmacy_purchase_return_from_store(uuid,uuid,jsonb,text,uuid,uuid)'::regprocedure); d:=replace(d,'''MAIN''','''MAIN-PHARMACY'''); execute d;
end $$;
