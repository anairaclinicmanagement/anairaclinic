-- Anaira Pharmacy ERP v0.8.160: authoritative multi-store inventory
-- Backfills legacy batch quantities to each clinic's Main Pharmacy store.
insert into public.pharmacy_stores(clinic_id,store_code,store_name,store_type,active)
select c.id,'MAIN','Main Pharmacy','pharmacy',true from public.clinics c on conflict(clinic_id,store_code) do nothing;
insert into public.pharmacy_store_stock(clinic_id,store_id,batch_id,medication_id,quantity)
select b.clinic_id,s.id,b.id,b.medication_id,greatest(b.quantity_on_hand,0) from public.inventory_batches b join public.pharmacy_stores s on s.clinic_id=b.clinic_id and s.store_code='MAIN' where b.quantity_on_hand>0 on conflict(clinic_id,store_id,batch_id) do nothing;
alter table public.pharmacy_dispense_allocations add column if not exists store_id uuid references public.pharmacy_stores(id);
alter table public.pharmacy_sales_returns add column if not exists store_id uuid references public.pharmacy_stores(id);
update public.pharmacy_dispense_allocations a set store_id=s.id from public.pharmacy_stores s where a.clinic_id=s.clinic_id and s.store_code='MAIN' and a.store_id is null;
update public.pharmacy_sales_returns r set store_id=a.store_id from public.pharmacy_dispense_allocations a where a.id=r.allocation_id and r.clinic_id=a.clinic_id and r.store_id is null;
create index if not exists pharmacy_dispense_allocations_store on public.pharmacy_dispense_allocations(clinic_id,store_id,medication_id,created_at desc);
create index if not exists pharmacy_store_stock_batch on public.pharmacy_store_stock(clinic_id,batch_id,store_id);
create index if not exists pharmacy_inventory_ledger_store_date on public.pharmacy_inventory_ledger(clinic_id,store_id,created_at desc);
alter table public.pharmacy_inventory_ledger enable row level security;
drop policy if exists pharmacy_inventory_ledger_clinic_access on public.pharmacy_inventory_ledger;
create policy pharmacy_inventory_ledger_clinic_access on public.pharmacy_inventory_ledger for all to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin','pharmacist','accountant'])) with check(private.has_clinic_role(clinic_id,array['owner','admin','pharmacist','accountant']));
create or replace view public.pharmacy_store_inventory_summary as
select ss.clinic_id,ss.store_id,st.store_name,st.store_type,ss.medication_id,m.name medicine_name,m.sku,m.barcode,count(*) filter(where ss.quantity>0)::int batch_count,sum(ss.quantity)::numeric(14,3) quantity_on_hand,sum(ss.quantity*b.purchase_rate)::numeric(14,2) stock_cost_value,sum(ss.quantity*b.sale_rate)::numeric(14,2) retail_value,sum(ss.quantity) filter(where b.expiry_date<current_date)::numeric(14,3) expired_qty,sum(ss.quantity) filter(where b.expiry_date between current_date and current_date+30)::numeric(14,3) expiring_30d_qty
from public.pharmacy_store_stock ss join public.pharmacy_stores st on st.id=ss.store_id and st.clinic_id=ss.clinic_id join public.inventory_batches b on b.id=ss.batch_id and b.clinic_id=ss.clinic_id join public.medications m on m.id=ss.medication_id and m.clinic_id=ss.clinic_id where st.active and coalesce(b.stock_condition,'saleable')='saleable' group by ss.clinic_id,ss.store_id,st.store_name,st.store_type,ss.medication_id,m.name,m.sku,m.barcode;
alter view public.pharmacy_store_inventory_summary set (security_invoker=true);
create or replace function public.pharmacy_submit_store_stock_count(p_clinic_id uuid,p_store_id uuid,p_batch_id uuid,p_physical_qty numeric,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); q numeric; cid uuid:=gen_random_uuid(); n text; med uuid;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Stock count permission required'; end if;
 if p_physical_qty<0 or not exists(select 1 from public.pharmacy_stores where id=p_store_id and clinic_id=p_clinic_id and active) then raise exception 'Invalid physical quantity or store'; end if;
 select ss.quantity,ss.medication_id into q,med from public.pharmacy_store_stock ss where ss.clinic_id=p_clinic_id and ss.store_id=p_store_id and ss.batch_id=p_batch_id for update;
 if q is null then raise exception 'Batch is not stocked in selected store'; end if;
 n:='CNT-'||upper(substr(replace(cid::text,'-',''),1,10));
 insert into public.pharmacy_stock_counts(id,clinic_id,count_no,store_id,status,counted_by,notes) values(cid,p_clinic_id,n,p_store_id,'pending',u,p_notes);
 insert into public.pharmacy_stock_count_items(clinic_id,count_id,batch_id,system_qty,physical_qty) values(p_clinic_id,cid,p_batch_id,q,p_physical_qty);
 return jsonb_build_object('id',cid,'count_no',n,'system_qty',q,'physical_qty',p_physical_qty,'variance',p_physical_qty-q);
end $$;
create or replace function public.pharmacy_approve_store_stock_count(p_clinic_id uuid,p_count_id uuid,p_approve boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r record; oldq numeric; delta numeric;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin']) then raise exception 'Only owner/admin may approve stock adjustments'; end if;
 select c.id,c.store_id,c.status,i.batch_id,i.system_qty,i.physical_qty,i.variance,b.medication_id into r from public.pharmacy_stock_counts c join public.pharmacy_stock_count_items i on i.count_id=c.id and i.clinic_id=c.clinic_id join public.inventory_batches b on b.id=i.batch_id and b.clinic_id=c.clinic_id where c.id=p_count_id and c.clinic_id=p_clinic_id and c.status='pending' for update of c;
 if not found or r.store_id is null then raise exception 'Pending store stock count not found'; end if;
 update public.pharmacy_stock_counts set status=case when p_approve then 'posted' else 'rejected' end,approved_by=u,approved_at=now() where id=p_count_id;
 if p_approve then
  select quantity into oldq from public.pharmacy_store_stock where clinic_id=p_clinic_id and store_id=r.store_id and batch_id=r.batch_id for update;
  if oldq is null then raise exception 'Store batch balance not found'; end if;
  delta:=r.physical_qty-oldq;
  update public.pharmacy_store_stock set quantity=r.physical_qty where clinic_id=p_clinic_id and store_id=r.store_id and batch_id=r.batch_id;
  update public.inventory_batches set quantity_on_hand=greatest(0,quantity_on_hand+delta) where id=r.batch_id and clinic_id=p_clinic_id;
  insert into public.pharmacy_inventory_ledger(clinic_id,store_id,batch_id,medication_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by) values(p_clinic_id,r.store_id,r.batch_id,r.medication_id,'stock_count_adjustment',delta,'stock_count',p_count_id,'Approved physical stock count',u);
  insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,r.batch_id,'adjustment',abs(delta),'stock_count',p_count_id,'Approved store physical count',u);
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_store_stock_count_decision','stock_count',p_count_id::text,jsonb_build_object('approved',p_approve,'store_id',r.store_id));
 return jsonb_build_object('id',p_count_id,'status',case when p_approve then 'posted' else 'rejected' end);
end $$;
create or replace function public.pharmacy_decide_sales_return_to_store(p_clinic_id uuid,p_return_id uuid,p_approve boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.pharmacy_sales_returns%rowtype; res jsonb; med uuid; st uuid;
begin
 select * into r from public.pharmacy_sales_returns where id=p_return_id and clinic_id=p_clinic_id for update;
 if not found then raise exception 'Sales return not found'; end if;
 st:=coalesce(r.store_id,(select id from public.pharmacy_stores where clinic_id=p_clinic_id and store_code='MAIN' limit 1));
 res:=public.pharmacy_decide_sales_return(p_clinic_id,p_return_id,p_approve);
 if p_approve then
  select medication_id into med from public.inventory_batches where id=r.batch_id and clinic_id=p_clinic_id;
  insert into public.pharmacy_store_stock(clinic_id,store_id,batch_id,medication_id,quantity) values(p_clinic_id,st,r.batch_id,med,r.quantity) on conflict(clinic_id,store_id,batch_id) do update set quantity=public.pharmacy_store_stock.quantity+excluded.quantity;
  update public.pharmacy_sales_returns set store_id=st where id=p_return_id and clinic_id=p_clinic_id;
  insert into public.pharmacy_inventory_ledger(clinic_id,store_id,batch_id,medication_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by) values(p_clinic_id,st,r.batch_id,med,'sales_return',r.quantity,'sales_return',p_return_id,'Approved customer return returned to originating store',u);
 end if;
 return res||jsonb_build_object('store_id',st);
end $$;
-- Store-scoped FEFO dispensing: clone existing atomic sale, deduct both batch and location balances, record ledger and allocation store.
do $$ declare d text; begin
 d:=pg_get_functiondef('public.dispense_pharmacy_sale(uuid,uuid,jsonb,uuid,text,boolean)'::regprocedure);
 d:=replace(d,'FUNCTION public.dispense_pharmacy_sale(','FUNCTION public.dispense_pharmacy_sale_from_store(');
 d:=replace(d,'p_collect_now boolean DEFAULT true)','p_collect_now boolean DEFAULT true, p_store_id uuid DEFAULT NULL::uuid)');
 d:=replace(d,'v_allocations jsonb; v_alloc jsonb;','v_allocations jsonb; v_alloc jsonb; v_store uuid;');
 d:=replace(d,'if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception ''Patient not found in this clinic''; end if;','if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception ''Patient not found in this clinic''; end if; v_store:=coalesce(p_store_id,(select id from public.pharmacy_stores where clinic_id=p_clinic_id and store_code=''MAIN'' and active limit 1)); if v_store is null or not exists(select 1 from public.pharmacy_stores where id=v_store and clinic_id=p_clinic_id and active) then raise exception ''Select an active pharmacy store''; end if;');
 d:=replace(d,'for v_batch in select b.id,b.quantity_on_hand,b.sale_rate,b.expiry_date from public.inventory_batches b where b.clinic_id=p_clinic_id and b.medication_id=v_med and b.quantity_on_hand>0 and coalesce(b.stock_condition,''saleable'')=''saleable'' and (b.expiry_date is null or b.expiry_date>=current_date) order by b.expiry_date asc nulls last,b.received_at asc for update loop','for v_batch in select b.id,b.quantity_on_hand,b.sale_rate,b.expiry_date,ss.quantity as store_quantity from public.inventory_batches b join public.pharmacy_store_stock ss on ss.batch_id=b.id and ss.clinic_id=b.clinic_id where b.clinic_id=p_clinic_id and ss.store_id=v_store and ss.quantity>0 and b.medication_id=v_med and b.quantity_on_hand>0 and coalesce(b.stock_condition,''saleable'')=''saleable'' and (b.expiry_date is null or b.expiry_date>=current_date) order by b.expiry_date asc nulls last,b.received_at asc for update of b,ss loop');
 d:=replace(d,'v_take:=least(v_left,v_batch.quantity_on_hand);','v_take:=least(v_left,least(v_batch.quantity_on_hand,v_batch.store_quantity));');
 d:=replace(d,'update public.inventory_batches set quantity_on_hand=quantity_on_hand-v_take where id=v_batch.id and clinic_id=p_clinic_id;','update public.inventory_batches set quantity_on_hand=quantity_on_hand-v_take where id=v_batch.id and clinic_id=p_clinic_id; update public.pharmacy_store_stock set quantity=quantity-v_take where clinic_id=p_clinic_id and store_id=v_store and batch_id=v_batch.id; insert into public.pharmacy_inventory_ledger(clinic_id,store_id,batch_id,medication_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_store,v_batch.id,v_med,''dispense'',-v_take,''pharmacy_invoice'',v_invoice,''Dispensed from selected store'',v_user);');
 d:=replace(d,'insert into public.pharmacy_dispense_allocations(clinic_id,invoice_id,invoice_item_id,batch_id,medication_id,dispensed_quantity) values(p_clinic_id,v_invoice,v_invoice_item,(v_alloc->>''batch_id'')::uuid,v_med,(v_alloc->>''quantity'')::numeric);','insert into public.pharmacy_dispense_allocations(clinic_id,invoice_id,invoice_item_id,batch_id,medication_id,dispensed_quantity,store_id) values(p_clinic_id,v_invoice,v_invoice_item,(v_alloc->>''batch_id'')::uuid,v_med,(v_alloc->>''quantity'')::numeric,v_store);');
 if position('ss.store_id=v_store' in d)=0 then raise exception 'Failed to construct store-scoped dispense function'; end if; execute d;
end $$;
do $$ declare d text; begin
 d:=pg_get_functiondef('public.dispense_pharmacy_sale_discounted(uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text)'::regprocedure);
 d:=replace(d,'FUNCTION public.dispense_pharmacy_sale_discounted(','FUNCTION public.dispense_pharmacy_sale_discounted_from_store(');
 d:=replace(d,'p_discount_reason text DEFAULT NULL::text)','p_discount_reason text DEFAULT NULL::text, p_store_id uuid DEFAULT NULL::uuid)');
 d:=replace(d,'public.dispense_pharmacy_sale(p_clinic_id,p_patient_id,v_items,p_prescription_id,p_payment_method,p_collect_now)','public.dispense_pharmacy_sale_from_store(p_clinic_id,p_patient_id,v_items,p_prescription_id,p_payment_method,p_collect_now,p_store_id)'); execute d;
end $$;
do $$ declare d text; begin
 d:=pg_get_functiondef('public.dispense_pharmacy_sale_for_admission(uuid,uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text)'::regprocedure);
 d:=replace(d,'FUNCTION public.dispense_pharmacy_sale_for_admission(','FUNCTION public.dispense_pharmacy_sale_for_admission_from_store(');
 d:=replace(d,'p_discount_reason text DEFAULT NULL::text)','p_discount_reason text DEFAULT NULL::text, p_store_id uuid DEFAULT NULL::uuid)');
 d:=replace(d,'public.dispense_pharmacy_sale_discounted(p_clinic_id,p_patient_id,p_items,p_prescription_id,p_payment_method,p_collect_now,p_discount_type,p_discount_value,p_discount_reason)','public.dispense_pharmacy_sale_discounted_from_store(p_clinic_id,p_patient_id,p_items,p_prescription_id,p_payment_method,p_collect_now,p_discount_type,p_discount_value,p_discount_reason,p_store_id)'); execute d;
end $$;
-- GRN receipts go into a selected store, not just the global batch total.
do $$ declare d text; begin
 d:=pg_get_functiondef('public.receive_pharmacy_grn(uuid,uuid,jsonb,uuid,text,date,numeric,text)'::regprocedure);
 d:=replace(d,'FUNCTION public.receive_pharmacy_grn(','FUNCTION public.receive_pharmacy_grn_to_store(');
 d:=replace(d,'p_notes text DEFAULT NULL::text)','p_notes text DEFAULT NULL::text, p_store_id uuid DEFAULT NULL::uuid)');
 d:=replace(d,'v_po_item uuid; v_po_qty numeric; v_received numeric;','v_po_item uuid; v_po_qty numeric; v_received numeric; v_store uuid;');
 d:=replace(d,'if not exists(select 1 from public.pharmacy_suppliers s where s.id=p_supplier_id and s.clinic_id=p_clinic_id and s.active) then raise exception ''Active supplier not found''; end if;','if not exists(select 1 from public.pharmacy_suppliers s where s.id=p_supplier_id and s.clinic_id=p_clinic_id and s.active) then raise exception ''Active supplier not found''; end if; v_store:=coalesce(p_store_id,(select id from public.pharmacy_stores where clinic_id=p_clinic_id and store_code=''MAIN'' and active limit 1)); if v_store is null or not exists(select 1 from public.pharmacy_stores where id=v_store and clinic_id=p_clinic_id and active) then raise exception ''Select an active receiving store''; end if;');
 d:=replace(d,'insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch_id,''purchase'',v_qty+v_free,''pharmacy_grn'',v_grn,''GRN ''||v_no,v_user);','insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch_id,''purchase'',v_qty+v_free,''pharmacy_grn'',v_grn,''GRN ''||v_no,v_user); insert into public.pharmacy_store_stock(clinic_id,store_id,batch_id,medication_id,quantity) values(p_clinic_id,v_store,v_batch_id,v_med,v_qty+v_free) on conflict(clinic_id,store_id,batch_id) do update set quantity=public.pharmacy_store_stock.quantity+excluded.quantity; insert into public.pharmacy_inventory_ledger(clinic_id,store_id,batch_id,medication_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_store,v_batch_id,v_med,''purchase_receipt'',v_qty+v_free,''pharmacy_grn'',v_grn,''GRN ''||v_no,v_user);');
 if position('purchase_receipt' in d)=0 then raise exception 'Failed to construct store-aware GRN'; end if; execute d;
end $$;
grant execute on function public.pharmacy_submit_store_stock_count(uuid,uuid,uuid,numeric,text) to authenticated;
grant execute on function public.pharmacy_approve_store_stock_count(uuid,uuid,boolean) to authenticated;
grant execute on function public.pharmacy_decide_sales_return_to_store(uuid,uuid,boolean) to authenticated;
grant execute on function public.dispense_pharmacy_sale_from_store(uuid,uuid,jsonb,uuid,text,boolean,uuid) to authenticated;
grant execute on function public.dispense_pharmacy_sale_discounted_from_store(uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text,uuid) to authenticated;
grant execute on function public.dispense_pharmacy_sale_for_admission_from_store(uuid,uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text,uuid) to authenticated;
grant execute on function public.receive_pharmacy_grn_to_store(uuid,uuid,jsonb,uuid,text,date,numeric,text,uuid) to authenticated;
