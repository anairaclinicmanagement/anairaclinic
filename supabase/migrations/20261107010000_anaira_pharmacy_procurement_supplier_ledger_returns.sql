-- Anaira Pharmacy ERP foundation: procurement, GRN, supplier ledger, purchase returns.
-- All writes are clinic-scoped, transactional, role-checked and audit logged.
create table if not exists public.pharmacy_purchase_orders (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 po_no text not null,
 supplier_id uuid not null references public.pharmacy_suppliers(id) on delete restrict,
 status text not null default 'draft' check(status in ('draft','ordered','part_received','received','cancelled')),
 order_date date not null default current_date,
 expected_date date,
 subtotal numeric(14,2) not null default 0 check(subtotal>=0),
 tax_amount numeric(14,2) not null default 0 check(tax_amount>=0),
 total_amount numeric(14,2) not null default 0 check(total_amount>=0),
 notes text,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(clinic_id,po_no)
);
create table if not exists public.pharmacy_purchase_order_items (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 purchase_order_id uuid not null references public.pharmacy_purchase_orders(id) on delete cascade,
 medication_id uuid not null references public.medications(id) on delete restrict,
 ordered_qty numeric(14,3) not null check(ordered_qty>0),
 received_qty numeric(14,3) not null default 0 check(received_qty>=0),
 free_qty numeric(14,3) not null default 0 check(free_qty>=0),
 purchase_rate numeric(14,2) not null default 0 check(purchase_rate>=0),
 tax_percent numeric(5,2) not null default 0 check(tax_percent between 0 and 100),
 line_total numeric(14,2) not null default 0 check(line_total>=0),
 created_at timestamptz not null default now()
);
create table if not exists public.pharmacy_goods_receipts (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 grn_no text not null,
 purchase_order_id uuid references public.pharmacy_purchase_orders(id) on delete restrict,
 supplier_id uuid not null references public.pharmacy_suppliers(id) on delete restrict,
 supplier_invoice_no text,
 supplier_invoice_date date,
 invoice_total numeric(14,2) not null default 0 check(invoice_total>=0),
 status text not null default 'posted' check(status in ('posted','reversed')),
 received_by uuid references auth.users(id),
 received_at timestamptz not null default now(),
 notes text,
 unique(clinic_id,grn_no)
);
create table if not exists public.pharmacy_goods_receipt_items (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 grn_id uuid not null references public.pharmacy_goods_receipts(id) on delete cascade,
 medication_id uuid not null references public.medications(id) on delete restrict,
 batch_id uuid not null references public.inventory_batches(id) on delete restrict,
 batch_number text not null,
 expiry_date date,
 quantity numeric(14,3) not null check(quantity>0),
 free_quantity numeric(14,3) not null default 0 check(free_quantity>=0),
 purchase_rate numeric(14,2) not null default 0 check(purchase_rate>=0),
 sale_rate numeric(14,2) not null default 0 check(sale_rate>=0),
 tax_percent numeric(5,2) not null default 0 check(tax_percent between 0 and 100)
);
create table if not exists public.pharmacy_supplier_ledger (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 supplier_id uuid not null references public.pharmacy_suppliers(id) on delete restrict,
 entry_type text not null check(entry_type in ('purchase','payment','purchase_return','debit_note','opening')),
 reference_type text not null,
 reference_id uuid,
 reference_no text,
 debit numeric(14,2) not null default 0 check(debit>=0),
 credit numeric(14,2) not null default 0 check(credit>=0),
 entry_date date not null default current_date,
 notes text,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 check(not (debit>0 and credit>0))
);
create table if not exists public.pharmacy_purchase_returns (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 return_no text not null,
 supplier_id uuid not null references public.pharmacy_suppliers(id) on delete restrict,
 grn_id uuid references public.pharmacy_goods_receipts(id) on delete restrict,
 status text not null default 'posted' check(status in ('posted','cancelled')),
 total_amount numeric(14,2) not null default 0 check(total_amount>=0),
 reason text not null,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 unique(clinic_id,return_no)
);
create table if not exists public.pharmacy_purchase_return_items (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 return_id uuid not null references public.pharmacy_purchase_returns(id) on delete cascade,
 batch_id uuid not null references public.inventory_batches(id) on delete restrict,
 medication_id uuid not null references public.medications(id) on delete restrict,
 quantity numeric(14,3) not null check(quantity>0),
 unit_rate numeric(14,2) not null check(unit_rate>=0),
 line_total numeric(14,2) not null check(line_total>=0)
);
create index if not exists pharmacy_po_clinic_date_idx on public.pharmacy_purchase_orders(clinic_id,order_date desc);
create index if not exists pharmacy_grn_clinic_date_idx on public.pharmacy_goods_receipts(clinic_id,received_at desc);
create index if not exists pharmacy_supplier_ledger_idx on public.pharmacy_supplier_ledger(clinic_id,supplier_id,entry_date desc);
create index if not exists pharmacy_purchase_returns_idx on public.pharmacy_purchase_returns(clinic_id,created_at desc);
do $$ declare t text; begin
 foreach t in array array['pharmacy_purchase_orders','pharmacy_purchase_order_items','pharmacy_goods_receipts','pharmacy_goods_receipt_items','pharmacy_supplier_ledger','pharmacy_purchase_returns','pharmacy_purchase_return_items'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists %I on public.%I',t||'_select',t);
  execute format('create policy %I on public.%I for select to authenticated using(private.has_clinic_role(clinic_id,array[''owner'',''admin'',''pharmacist'',''accountant'']))',t||'_select',t);
  execute format('drop policy if exists %I on public.%I',t||'_insert',t);
  execute format('create policy %I on public.%I for insert to authenticated with check(private.has_clinic_role(clinic_id,array[''owner'',''admin'',''pharmacist'']))',t||'_insert',t);
 end loop;
end $$;

create or replace function public.create_pharmacy_purchase_order(
 p_clinic_id uuid,p_supplier_id uuid,p_items jsonb,p_expected_date date default null,p_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_po uuid:=gen_random_uuid(); v_no text; v_item jsonb; v_med uuid; v_qty numeric; v_rate numeric; v_tax numeric; v_free numeric; v_sub numeric:=0; v_tax_total numeric:=0; v_count int:=0;
begin
 if v_user is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Purchase order permission required'; end if;
 if not public.clinic_module_access(p_clinic_id,'pharmacy') then raise exception 'Pharmacy module is disabled'; end if;
 if not exists(select 1 from public.pharmacy_suppliers s where s.id=p_supplier_id and s.clinic_id=p_clinic_id and s.active) then raise exception 'Active supplier not found'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'At least one purchase item is required'; end if;
 v_no:='PO-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_po::text,'-',''),1,7));
 insert into public.pharmacy_purchase_orders(id,clinic_id,po_no,supplier_id,status,expected_date,notes,created_by) values(v_po,p_clinic_id,v_no,p_supplier_id,'ordered',p_expected_date,nullif(trim(coalesce(p_notes,'')),''),v_user);
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_med:=nullif(v_item->>'medication_id','')::uuid; v_qty:=nullif(v_item->>'quantity','')::numeric; v_rate:=coalesce(nullif(v_item->>'purchase_rate','')::numeric,0); v_tax:=coalesce(nullif(v_item->>'tax_percent','')::numeric,0); v_free:=coalesce(nullif(v_item->>'free_quantity','')::numeric,0);
  if not exists(select 1 from public.medications m where m.id=v_med and m.clinic_id=p_clinic_id and m.active) then raise exception 'Invalid active medicine in purchase order'; end if;
  if v_qty<=0 or v_free<0 or v_rate<0 or v_tax<0 or v_tax>100 then raise exception 'Invalid purchase quantity, rate, free quantity or tax'; end if;
  insert into public.pharmacy_purchase_order_items(clinic_id,purchase_order_id,medication_id,ordered_qty,free_qty,purchase_rate,tax_percent,line_total)
  values(p_clinic_id,v_po,v_med,v_qty,v_free,v_rate,v_tax,round(v_qty*v_rate*(1+v_tax/100),2));
  v_sub:=v_sub+v_qty*v_rate; v_tax_total:=v_tax_total+round(v_qty*v_rate*v_tax/100,2); v_count:=v_count+1;
 end loop;
 update public.pharmacy_purchase_orders set subtotal=round(v_sub,2),tax_amount=round(v_tax_total,2),total_amount=round(v_sub+v_tax_total,2) where id=v_po;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_pharmacy_purchase_order','purchase_order',v_po::text,jsonb_build_object('po_no',v_no,'supplier_id',p_supplier_id,'items',v_count,'total',v_sub+v_tax_total));
 return jsonb_build_object('id',v_po,'po_no',v_no,'subtotal',round(v_sub,2),'tax_amount',round(v_tax_total,2),'total_amount',round(v_sub+v_tax_total,2),'item_count',v_count);
end $$;

create or replace function public.receive_pharmacy_grn(
 p_clinic_id uuid,p_supplier_id uuid,p_items jsonb,p_purchase_order_id uuid default null,
 p_supplier_invoice_no text default null,p_supplier_invoice_date date default null,p_invoice_total numeric default null,p_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_grn uuid:=gen_random_uuid(); v_no text; v_item jsonb; v_med uuid; v_batch text; v_exp date; v_qty numeric; v_free numeric; v_rate numeric; v_sale numeric; v_tax numeric; v_batch_id uuid; v_total numeric:=0; v_count int:=0; v_po_item uuid; v_po_qty numeric; v_received numeric;
begin
 if v_user is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Goods receipt permission required'; end if;
 if not exists(select 1 from public.pharmacy_suppliers s where s.id=p_supplier_id and s.clinic_id=p_clinic_id and s.active) then raise exception 'Active supplier not found'; end if;
 if p_purchase_order_id is not null and not exists(select 1 from public.pharmacy_purchase_orders po where po.id=p_purchase_order_id and po.clinic_id=p_clinic_id and po.supplier_id=p_supplier_id and po.status in ('ordered','part_received')) then raise exception 'Open purchase order not found for supplier'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'At least one received item is required'; end if;
 v_no:='GRN-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_grn::text,'-',''),1,7));
 insert into public.pharmacy_goods_receipts(id,clinic_id,grn_no,purchase_order_id,supplier_id,supplier_invoice_no,supplier_invoice_date,invoice_total,received_by,notes)
 values(v_grn,p_clinic_id,v_no,p_purchase_order_id,p_supplier_id,nullif(trim(coalesce(p_supplier_invoice_no,'')),''),p_supplier_invoice_date,coalesce(p_invoice_total,0),v_user,nullif(trim(coalesce(p_notes,'')),''));
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_med:=nullif(v_item->>'medication_id','')::uuid; v_batch:=trim(coalesce(v_item->>'batch_number','')); v_exp:=nullif(v_item->>'expiry_date','')::date; v_qty:=nullif(v_item->>'quantity','')::numeric; v_free:=coalesce(nullif(v_item->>'free_quantity','')::numeric,0); v_rate:=coalesce(nullif(v_item->>'purchase_rate','')::numeric,0); v_sale:=coalesce(nullif(v_item->>'sale_rate','')::numeric,0); v_tax:=coalesce(nullif(v_item->>'tax_percent','')::numeric,0);
  if not exists(select 1 from public.medications m where m.id=v_med and m.clinic_id=p_clinic_id and m.active) then raise exception 'Invalid active medicine in GRN'; end if;
  if v_batch='' or v_qty<=0 or v_free<0 or v_rate<0 or v_sale<0 or v_tax<0 or v_tax>100 or (v_exp is not null and v_exp<current_date) then raise exception 'Invalid batch, expiry, quantity, rate or tax in GRN'; end if;
  if p_purchase_order_id is not null then
   select id,ordered_qty,received_qty into v_po_item,v_po_qty,v_received from public.pharmacy_purchase_order_items where clinic_id=p_clinic_id and purchase_order_id=p_purchase_order_id and medication_id=v_med order by created_at limit 1 for update;
   if v_po_item is null or v_received+v_qty>v_po_qty then raise exception 'GRN quantity exceeds open PO quantity for medicine %',v_med; end if;
   update public.pharmacy_purchase_order_items set received_qty=received_qty+v_qty where id=v_po_item;
  end if;
  select id into v_batch_id from public.inventory_batches where clinic_id=p_clinic_id and medication_id=v_med and batch_number=v_batch for update;
  if v_batch_id is null then
   insert into public.inventory_batches(clinic_id,medication_id,batch_number,expiry_date,quantity_on_hand,purchase_rate,sale_rate,supplier_name,received_at)
   values(p_clinic_id,v_med,v_batch,v_exp,v_qty+v_free,v_rate,v_sale,(select supplier_name from public.pharmacy_suppliers where id=p_supplier_id),now()) returning id into v_batch_id;
  else
   update public.inventory_batches set quantity_on_hand=quantity_on_hand+v_qty+v_free,expiry_date=coalesce(v_exp,expiry_date),purchase_rate=v_rate,sale_rate=v_sale,supplier_name=(select supplier_name from public.pharmacy_suppliers where id=p_supplier_id) where id=v_batch_id;
  end if;
  insert into public.pharmacy_goods_receipt_items(clinic_id,grn_id,medication_id,batch_id,batch_number,expiry_date,quantity,free_quantity,purchase_rate,sale_rate,tax_percent)
  values(p_clinic_id,v_grn,v_med,v_batch_id,v_batch,v_exp,v_qty,v_free,v_rate,v_sale,v_tax);
  insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by)
  values(p_clinic_id,v_batch_id,'purchase',v_qty+v_free,'pharmacy_grn',v_grn,'GRN '||v_no,v_user);
  v_total:=v_total+round(v_qty*v_rate*(1+v_tax/100),2); v_count:=v_count+1;
 end loop;
 if p_invoice_total is not null and abs(p_invoice_total-v_total)>1 then raise exception 'Supplier invoice total differs from GRN calculated total; reconcile before posting'; end if;
 update public.pharmacy_goods_receipts set invoice_total=coalesce(p_invoice_total,v_total) where id=v_grn;
 insert into public.pharmacy_supplier_ledger(clinic_id,supplier_id,entry_type,reference_type,reference_id,reference_no,debit,entry_date,notes,created_by)
 values(p_clinic_id,p_supplier_id,'purchase','grn',v_grn,v_no,coalesce(p_invoice_total,v_total),current_date,'Supplier invoice '||coalesce(p_supplier_invoice_no,v_no),v_user);
 if p_purchase_order_id is not null then
  update public.pharmacy_purchase_orders po set status=case when not exists(select 1 from public.pharmacy_purchase_order_items i where i.purchase_order_id=po.id and i.clinic_id=p_clinic_id and i.received_qty<i.ordered_qty) then 'received' else 'part_received' end,updated_at=now() where po.id=p_purchase_order_id;
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'receive_pharmacy_grn','goods_receipt',v_grn::text,jsonb_build_object('grn_no',v_no,'supplier_id',p_supplier_id,'items',v_count,'total',coalesce(p_invoice_total,v_total)));
 return jsonb_build_object('id',v_grn,'grn_no',v_no,'total_amount',coalesce(p_invoice_total,v_total),'item_count',v_count);
end $$;

create or replace function public.record_pharmacy_supplier_payment(p_clinic_id uuid,p_supplier_id uuid,p_amount numeric,p_method text,p_reference text default null,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid:=gen_random_uuid(); v_no text;
begin
 if v_user is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','accountant']) then raise exception 'Supplier payment requires Admin/Owner/Accountant approval'; end if;
 if not exists(select 1 from public.pharmacy_suppliers where id=p_supplier_id and clinic_id=p_clinic_id) then raise exception 'Supplier not found'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Payment amount must be positive'; end if;
 if p_method not in ('cash','card','upi','bank_transfer','cheque') then raise exception 'Unsupported supplier payment method'; end if;
 v_no:='SPAY-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_id::text,'-',''),1,7));
 insert into public.pharmacy_supplier_ledger(clinic_id,supplier_id,entry_type,reference_type,reference_id,reference_no,credit,notes,created_by)
 values(p_clinic_id,p_supplier_id,'payment','supplier_payment',v_id,v_no,p_amount,coalesce(p_notes,'')||case when p_reference is not null then ' | Ref: '||p_reference else '' end,v_user);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_pharmacy_supplier_payment','supplier_payment',v_id::text,jsonb_build_object('supplier_id',p_supplier_id,'amount',p_amount,'method',p_method,'reference',p_reference));
 return jsonb_build_object('id',v_id,'payment_no',v_no,'amount',p_amount,'method',p_method);
end $$;

create or replace function public.create_pharmacy_purchase_return(p_clinic_id uuid,p_supplier_id uuid,p_items jsonb,p_reason text,p_grn_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid:=gen_random_uuid(); v_no text; v_item jsonb; v_batch uuid; v_med uuid; v_qty numeric; v_rate numeric; v_before numeric; v_total numeric:=0; v_count int:=0;
begin
 if v_user is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Purchase return permission required'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'Return reason is required'; end if;
 if not exists(select 1 from public.pharmacy_suppliers where id=p_supplier_id and clinic_id=p_clinic_id) then raise exception 'Supplier not found'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'At least one return item is required'; end if;
 v_no:='PR-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_id::text,'-',''),1,7));
 insert into public.pharmacy_purchase_returns(id,clinic_id,return_no,supplier_id,grn_id,reason,created_by) values(v_id,p_clinic_id,v_no,p_supplier_id,p_grn_id,trim(p_reason),v_user);
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_batch:=nullif(v_item->>'batch_id','')::uuid; v_qty:=nullif(v_item->>'quantity','')::numeric; v_rate:=coalesce(nullif(v_item->>'unit_rate','')::numeric,0);
  select medication_id,quantity_on_hand into v_med,v_before from public.inventory_batches where id=v_batch and clinic_id=p_clinic_id for update;
  if v_med is null or v_qty<=0 or v_qty>v_before or v_rate<0 then raise exception 'Invalid return quantity or batch stock'; end if;
  update public.inventory_batches set quantity_on_hand=quantity_on_hand-v_qty where id=v_batch and clinic_id=p_clinic_id;
  insert into public.pharmacy_purchase_return_items(clinic_id,return_id,batch_id,medication_id,quantity,unit_rate,line_total) values(p_clinic_id,v_id,v_batch,v_med,v_qty,v_rate,round(v_qty*v_rate,2));
  insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch,'adjustment',v_qty,'purchase_return',v_id,'Purchase return '||v_no||' | '||trim(p_reason),v_user);
  v_total:=v_total+v_qty*v_rate; v_count:=v_count+1;
 end loop;
 update public.pharmacy_purchase_returns set total_amount=round(v_total,2) where id=v_id;
 insert into public.pharmacy_supplier_ledger(clinic_id,supplier_id,entry_type,reference_type,reference_id,reference_no,credit,notes,created_by)
 values(p_clinic_id,p_supplier_id,'purchase_return','purchase_return',v_id,v_no,round(v_total,2),trim(p_reason),v_user);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_pharmacy_purchase_return','purchase_return',v_id::text,jsonb_build_object('return_no',v_no,'supplier_id',p_supplier_id,'items',v_count,'total',v_total,'reason',p_reason));
 return jsonb_build_object('id',v_id,'return_no',v_no,'total_amount',round(v_total,2),'item_count',v_count);
end $$;

revoke all on function public.create_pharmacy_purchase_order(uuid,uuid,jsonb,date,text) from public,anon;
revoke all on function public.receive_pharmacy_grn(uuid,uuid,jsonb,uuid,text,date,numeric,text) from public,anon;
revoke all on function public.record_pharmacy_supplier_payment(uuid,uuid,numeric,text,text,text) from public,anon;
revoke all on function public.create_pharmacy_purchase_return(uuid,uuid,jsonb,text,uuid) from public,anon;
grant execute on function public.create_pharmacy_purchase_order(uuid,uuid,jsonb,date,text) to authenticated;
grant execute on function public.receive_pharmacy_grn(uuid,uuid,jsonb,uuid,text,date,numeric,text) to authenticated;
grant execute on function public.record_pharmacy_supplier_payment(uuid,uuid,numeric,text,text,text) to authenticated;
grant execute on function public.create_pharmacy_purchase_return(uuid,uuid,jsonb,text,uuid) to authenticated;
