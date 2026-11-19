-- Source snapshot for DB migration 20261106205414. Idempotent schema/function definitions also exist in the v0.8.156 inventory-controls foundation.
-- Anaira Pharmacy ERP v0.8.156: inventory controls, multi-store, audit counts, sales return and registers.
-- This migration is already applied in the linked Anaira Clinic project (version 20261106204402).
alter table public.inventory_batches add column if not exists stock_condition text not null default 'saleable';
alter table public.inventory_batches add column if not exists quarantine_reason text;
create table if not exists public.pharmacy_dispense_allocations(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 invoice_id uuid not null references public.invoices(id) on delete cascade, invoice_item_id uuid not null references public.invoice_items(id) on delete cascade,
 batch_id uuid not null references public.inventory_batches(id), medication_id uuid not null references public.medications(id),
 dispensed_quantity numeric(14,3) not null check(dispensed_quantity>0), created_at timestamptz not null default now());
create index if not exists pharmacy_dispense_allocations_invoice on public.pharmacy_dispense_allocations(clinic_id,invoice_id,invoice_item_id);
alter table public.pharmacy_sales_returns add column if not exists allocation_id uuid references public.pharmacy_dispense_allocations(id);
create table if not exists public.pharmacy_stores(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 store_code text not null, store_name text not null, store_type text not null check(store_type in ('pharmacy','ward','ot','icu','branch','other')),
 branch_id uuid references public.clinic_branches(id), active boolean not null default true, created_at timestamptz not null default now(), unique(clinic_id,store_code));
create table if not exists public.pharmacy_store_stock(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 store_id uuid not null references public.pharmacy_stores(id), batch_id uuid not null references public.inventory_batches(id),
 medication_id uuid not null references public.medications(id), quantity numeric(14,3) not null default 0 check(quantity>=0), unique(clinic_id,store_id,batch_id));
create table if not exists public.pharmacy_stock_transfers(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 transfer_no text not null, from_store_id uuid not null references public.pharmacy_stores(id), to_store_id uuid not null references public.pharmacy_stores(id),
 status text not null default 'posted' check(status in ('posted','cancelled')), reason text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(clinic_id,transfer_no));
create table if not exists public.pharmacy_stock_transfer_items(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 transfer_id uuid not null references public.pharmacy_stock_transfers(id) on delete cascade, batch_id uuid not null references public.inventory_batches(id),
 medication_id uuid not null references public.medications(id), quantity numeric(14,3) not null check(quantity>0));
create table if not exists public.pharmacy_stock_counts(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 count_no text not null, store_id uuid references public.pharmacy_stores(id), status text not null default 'pending' check(status in ('pending','approved','rejected','posted')),
 counted_by uuid references auth.users(id), approved_by uuid references auth.users(id), approved_at timestamptz, notes text, created_at timestamptz not null default now(), unique(clinic_id,count_no));
create table if not exists public.pharmacy_stock_count_items(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 count_id uuid not null references public.pharmacy_stock_counts(id) on delete cascade, batch_id uuid not null references public.inventory_batches(id),
 system_qty numeric(14,3) not null, physical_qty numeric(14,3) not null check(physical_qty>=0), variance numeric(14,3) generated always as (physical_qty-system_qty) stored);
create table if not exists public.pharmacy_sales_returns(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 return_no text not null, invoice_id uuid not null references public.invoices(id), invoice_item_id uuid not null references public.invoice_items(id),
 batch_id uuid not null references public.inventory_batches(id), quantity numeric(14,3) not null check(quantity>0), refund_amount numeric(14,2) not null check(refund_amount>=0),
 reason text not null, status text not null default 'pending' check(status in ('pending','approved','rejected','refunded')),
 requested_by uuid references auth.users(id), approved_by uuid references auth.users(id), allocation_id uuid references public.pharmacy_dispense_allocations(id), created_at timestamptz not null default now(), unique(clinic_id,return_no));
create table if not exists public.pharmacy_unit_conversions(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 medication_id uuid not null references public.medications(id) on delete cascade, from_unit text not null, to_unit text not null,
 factor numeric(14,4) not null check(factor>0), active boolean not null default true, unique(clinic_id,medication_id,from_unit,to_unit));
create table if not exists public.pharmacy_drug_register(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 schedule_code text not null check(schedule_code in ('H','H1','X')), invoice_id uuid references public.invoices(id),
 medication_id uuid not null references public.medications(id), patient_id uuid references public.patients(id),
 prescriber_name text, prescription_reference text, quantity numeric(14,3) not null check(quantity>0), dispensed_by uuid references auth.users(id),
 dispensed_at timestamptz not null default now(), notes text);
create table if not exists public.pharmacy_cashier_shifts(
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 shift_no text not null, cashier_id uuid not null references auth.users(id), opened_at timestamptz not null default now(),
 opening_cash numeric(14,2) not null default 0 check(opening_cash>=0), closed_at timestamptz,
 expected_cash numeric(14,2), counted_cash numeric(14,2), cash_variance numeric(14,2), status text not null default 'open' check(status in ('open','closed')),
 notes text, unique(clinic_id,shift_no));
create index if not exists pharmacy_store_stock_lookup on public.pharmacy_store_stock(clinic_id,store_id,medication_id);
create index if not exists pharmacy_sales_returns_invoice on public.pharmacy_sales_returns(clinic_id,invoice_id);
create index if not exists pharmacy_drug_register_date on public.pharmacy_drug_register(clinic_id,schedule_code,dispensed_at desc);
create index if not exists pharmacy_cashier_shifts_cashier on public.pharmacy_cashier_shifts(clinic_id,cashier_id,status);
do $$ declare t text; begin foreach t in array array['pharmacy_dispense_allocations','pharmacy_stores','pharmacy_store_stock','pharmacy_stock_transfers','pharmacy_stock_transfer_items','pharmacy_stock_counts','pharmacy_stock_count_items','pharmacy_sales_returns','pharmacy_unit_conversions','pharmacy_drug_register','pharmacy_cashier_shifts'] loop execute format('alter table public.%I enable row level security',t); execute format('drop policy if exists %I on public.%I',t||'_clinic_access',t); execute format('create policy %I on public.%I for all to authenticated using(private.has_clinic_role(clinic_id,array[''owner'',''admin'',''pharmacist'',''accountant''])) with check(private.has_clinic_role(clinic_id,array[''owner'',''admin'',''pharmacist'',''accountant'']))',t||'_clinic_access',t); end loop; end $$;
create or replace function public.create_pharmacy_sales_return(p_clinic_id uuid,p_invoice_id uuid,p_invoice_item_id uuid,p_batch_id uuid,p_quantity numeric,p_refund_amount numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a public.pharmacy_dispense_allocations%rowtype; returned numeric; rid uuid:=gen_random_uuid(); n text;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Sales return permission required'; end if;
 if p_quantity<=0 or p_refund_amount<0 or nullif(trim(p_reason),'') is null then raise exception 'Quantity, refund and reason are required'; end if;
 select * into a from public.pharmacy_dispense_allocations where clinic_id=p_clinic_id and invoice_id=p_invoice_id and invoice_item_id=p_invoice_item_id and batch_id=p_batch_id limit 1 for update;
 if not found then raise exception 'This invoice item has no recorded batch allocation. Only traceable sales can be returned'; end if;
 select coalesce(sum(quantity),0) into returned from public.pharmacy_sales_returns where allocation_id=a.id and status in ('pending','approved','refunded');
 if returned+p_quantity>a.dispensed_quantity then raise exception 'Return quantity exceeds unreturned dispensed quantity'; end if;
 n:='SR-'||upper(substr(replace(rid::text,'-',''),1,10));
 insert into public.pharmacy_sales_returns(id,clinic_id,return_no,invoice_id,invoice_item_id,batch_id,allocation_id,quantity,refund_amount,reason,status,requested_by)
 values(rid,p_clinic_id,n,p_invoice_id,p_invoice_item_id,p_batch_id,a.id,p_quantity,p_refund_amount,trim(p_reason),'pending',u);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_sales_return_requested','sales_return',rid::text,jsonb_build_object('invoice',p_invoice_id,'invoice_item',p_invoice_item_id,'batch',p_batch_id,'quantity',p_quantity,'refund',p_refund_amount));
 return jsonb_build_object('id',rid,'return_no',n,'status','pending');
end $$;
create or replace function public.pharmacy_decide_sales_return(p_clinic_id uuid,p_return_id uuid,p_approve boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.pharmacy_sales_returns%rowtype;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin']) then raise exception 'Only owner/admin may approve sales returns'; end if;
 select * into r from public.pharmacy_sales_returns where id=p_return_id and clinic_id=p_clinic_id and status='pending' for update;
 if not found then raise exception 'Pending sales return not found'; end if;
 if p_approve then
  update public.inventory_batches set quantity_on_hand=quantity_on_hand+r.quantity,stock_condition='saleable' where id=r.batch_id and clinic_id=p_clinic_id;
  insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,r.batch_id,'return',r.quantity,'pharmacy_sales_return',r.id,'Approved saleable customer return',u);
  update public.pharmacy_sales_returns set status='approved',approved_by=u where id=r.id;
 else update public.pharmacy_sales_returns set status='rejected',approved_by=u where id=r.id; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_sales_return_decision','sales_return',r.id::text,jsonb_build_object('approved',p_approve,'refund_amount',r.refund_amount,'stock_restored',case when p_approve then r.quantity else 0 end));
 return jsonb_build_object('id',r.id,'status',case when p_approve then 'approved' else 'rejected' end,'refund_amount',r.refund_amount);
end $$;
revoke all on function public.create_pharmacy_sales_return(uuid,uuid,uuid,uuid,numeric,numeric,text) from public,anon;
revoke all on function public.pharmacy_decide_sales_return(uuid,uuid,boolean) from public,anon;
grant execute on function public.create_pharmacy_sales_return(uuid,uuid,uuid,uuid,numeric,numeric,text) to authenticated;
grant execute on function public.pharmacy_decide_sales_return(uuid,uuid,boolean) to authenticated;
create or replace function public.pharmacy_post_stock_transfer(p_clinic_id uuid,p_from_store uuid,p_to_store uuid,p_batch_id uuid,p_quantity numeric,p_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a numeric; tid uuid:=gen_random_uuid(); n text;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Transfer permission required'; end if;
 if p_from_store=p_to_store or p_quantity<=0 then raise exception 'Choose different stores and a positive quantity'; end if;
 if not exists(select 1 from public.pharmacy_stores where id=p_from_store and clinic_id=p_clinic_id and active) or not exists(select 1 from public.pharmacy_stores where id=p_to_store and clinic_id=p_clinic_id and active) then raise exception 'Store not found'; end if;
 select quantity into a from public.pharmacy_store_stock where clinic_id=p_clinic_id and store_id=p_from_store and batch_id=p_batch_id for update;
 if coalesce(a,0)<p_quantity then raise exception 'Insufficient source-store stock'; end if;
 n:='TR-'||upper(substr(replace(tid::text,'-',''),1,10));
 insert into public.pharmacy_stock_transfers(id,clinic_id,transfer_no,from_store_id,to_store_id,reason,created_by) values(tid,p_clinic_id,n,p_from_store,p_to_store,p_reason,u);
 update public.pharmacy_store_stock set quantity=quantity-p_quantity where clinic_id=p_clinic_id and store_id=p_from_store and batch_id=p_batch_id;
 insert into public.pharmacy_store_stock(clinic_id,store_id,batch_id,medication_id,quantity) select p_clinic_id,p_to_store,p_batch_id,medication_id,p_quantity from public.inventory_batches where id=p_batch_id and clinic_id=p_clinic_id on conflict(clinic_id,store_id,batch_id) do update set quantity=pharmacy_store_stock.quantity+excluded.quantity;
 insert into public.pharmacy_stock_transfer_items(clinic_id,transfer_id,batch_id,medication_id,quantity) select p_clinic_id,tid,p_batch_id,medication_id,p_quantity from public.inventory_batches where id=p_batch_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_stock_transfer','stock_transfer',tid::text,jsonb_build_object('from',p_from_store,'to',p_to_store,'batch',p_batch_id,'quantity',p_quantity));
 return jsonb_build_object('id',tid,'transfer_no',n);
end $$;
create or replace function public.pharmacy_submit_stock_count(p_clinic_id uuid,p_batch_id uuid,p_physical_qty numeric,p_notes text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); q numeric; cid uuid:=gen_random_uuid(); n text;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Stock count permission required'; end if;
 if p_physical_qty<0 then raise exception 'Physical quantity cannot be negative'; end if;
 select quantity_on_hand into q from public.inventory_batches where id=p_batch_id and clinic_id=p_clinic_id for update;
 if q is null then raise exception 'Batch not found'; end if;
 n:='CNT-'||upper(substr(replace(cid::text,'-',''),1,10));
 insert into public.pharmacy_stock_counts(id,clinic_id,count_no,status,counted_by,notes) values(cid,p_clinic_id,n,'pending',u,p_notes);
 insert into public.pharmacy_stock_count_items(clinic_id,count_id,batch_id,system_qty,physical_qty) values(p_clinic_id,cid,p_batch_id,q,p_physical_qty);
 return jsonb_build_object('id',cid,'count_no',n,'system_qty',q,'physical_qty',p_physical_qty,'variance',p_physical_qty-q);
end $$;
create or replace function public.pharmacy_approve_stock_count(p_clinic_id uuid,p_count_id uuid,p_approve boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r record;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin']) then raise exception 'Only owner/admin may approve stock adjustments'; end if;
 select * into r from public.pharmacy_stock_counts where id=p_count_id and clinic_id=p_clinic_id and status='pending' for update;
 if not found then raise exception 'Pending stock count not found'; end if;
 update public.pharmacy_stock_counts set status=case when p_approve then 'posted' else 'rejected' end,approved_by=u,approved_at=now() where id=p_count_id;
 if p_approve then update public.inventory_batches b set quantity_on_hand=i.physical_qty from public.pharmacy_stock_count_items i where i.count_id=p_count_id and i.batch_id=b.id and b.clinic_id=p_clinic_id;
 insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) select p_clinic_id,i.batch_id,'adjustment',abs(i.variance),'stock_count',p_count_id,'Approved physical stock count',u from public.pharmacy_stock_count_items i where i.count_id=p_count_id and i.variance<>0; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_stock_count_decision','stock_count',p_count_id::text,jsonb_build_object('approved',p_approve));
 return jsonb_build_object('id',p_count_id,'status',case when p_approve then 'posted' else 'rejected' end);
end $$;
create or replace function public.pharmacy_open_cashier_shift(p_clinic_id uuid,p_opening_cash numeric) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); sid uuid:=gen_random_uuid(); n text;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Cashier shift permission required'; end if;
 if p_opening_cash<0 then raise exception 'Opening cash cannot be negative'; end if;
 if exists(select 1 from public.pharmacy_cashier_shifts where clinic_id=p_clinic_id and cashier_id=u and status='open') then raise exception 'You already have an open shift'; end if;
 n:='SHIFT-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD-HH24MISS');
 insert into public.pharmacy_cashier_shifts(clinic_id,shift_no,cashier_id,opening_cash) values(p_clinic_id,n,u,p_opening_cash) returning id into sid;
 return jsonb_build_object('id',sid,'shift_no',n);
end $$;
create or replace function public.pharmacy_close_cashier_shift(p_clinic_id uuid,p_shift_id uuid,p_counted_cash numeric,p_notes text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.pharmacy_cashier_shifts%rowtype; collected numeric:=0; refunds numeric:=0; expected numeric;
begin
 select * into r from public.pharmacy_cashier_shifts where id=p_shift_id and clinic_id=p_clinic_id and cashier_id=u and status='open' for update;
 if not found then raise exception 'Your open cashier shift was not found'; end if;
 if p_counted_cash<0 then raise exception 'Counted cash cannot be negative'; end if;
 select coalesce(sum(p.amount),0) into collected from public.payments p where p.clinic_id=p_clinic_id and p.received_by=u and p.paid_at>=r.opened_at and p.status in ('paid','completed','success');
 expected:=r.opening_cash+collected-refunds;
 update public.pharmacy_cashier_shifts set closed_at=now(),expected_cash=expected,counted_cash=p_counted_cash,cash_variance=p_counted_cash-expected,status='closed',notes=p_notes where id=p_shift_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_cashier_shift_closed','cashier_shift',p_shift_id::text,jsonb_build_object('collections',collected,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected));
 return jsonb_build_object('shift_no',r.shift_no,'opening_cash',r.opening_cash,'collections',collected,'refunds',refunds,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected);
end $$;
revoke all on function public.pharmacy_post_stock_transfer(uuid,uuid,uuid,uuid,numeric,text) from public,anon;
revoke all on function public.pharmacy_submit_stock_count(uuid,uuid,numeric,text) from public,anon;
revoke all on function public.pharmacy_approve_stock_count(uuid,uuid,boolean) from public,anon;
revoke all on function public.pharmacy_open_cashier_shift(uuid,numeric) from public,anon;
revoke all on function public.pharmacy_close_cashier_shift(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.pharmacy_post_stock_transfer(uuid,uuid,uuid,uuid,numeric,text) to authenticated;
grant execute on function public.pharmacy_submit_stock_count(uuid,uuid,numeric,text) to authenticated;
grant execute on function public.pharmacy_approve_stock_count(uuid,uuid,boolean) to authenticated;
grant execute on function public.pharmacy_open_cashier_shift(uuid,numeric) to authenticated;
grant execute on function public.pharmacy_close_cashier_shift(uuid,uuid,numeric,text) to authenticated;
