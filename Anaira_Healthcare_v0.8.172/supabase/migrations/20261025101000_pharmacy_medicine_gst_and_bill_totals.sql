-- Pharmacy medicine catalogue: per-medicine GST and GST-aware invoice totals.
alter table public.medications add column if not exists tax_percent numeric(5,2) not null default 0;
alter table public.medications drop constraint if exists medications_tax_percent_check;
alter table public.medications add constraint medications_tax_percent_check check (tax_percent >= 0 and tax_percent <= 100);
create or replace function public.dispense_pharmacy_sale(
 p_clinic_id uuid,p_patient_id uuid,p_items jsonb,p_prescription_id uuid default null,p_payment_method text default 'cash',p_collect_now boolean default true
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_invoice uuid; v_invoice_no text; v_item jsonb; v_med uuid; v_qty numeric; v_left numeric; v_take numeric; v_batch record; v_name text; v_price numeric; v_tax_percent numeric:=0; v_subtotal numeric:=0; v_tax numeric:=0; v_total numeric:=0; v_line numeric; v_line_tax numeric; v_line_total numeric; v_count integer:=0; v_paid numeric:=0; v_status text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Pharmacist/clinic admin permission required'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100 then raise exception 'Add between 1 and 100 sale items'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 if p_prescription_id is not null and not exists(select 1 from public.prescriptions r where r.id=p_prescription_id and r.clinic_id=p_clinic_id and r.patient_id=p_patient_id and r.status in ('signed','dispensed') and coalesce(r.valid_until,r.prescribed_at::date+r.validity_days)>=current_date) then raise exception 'Prescription expired, cancelled or does not belong to this patient. Create a new prescription.'; end if;
 v_invoice:=gen_random_uuid(); v_invoice_no:='PH-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,p_patient_id,v_invoice_no,'draft',0,0,0,now(),v_user);
 for v_item in select value from jsonb_array_elements(p_items) loop
   v_med:=nullif(v_item->>'medication_id','')::uuid; v_qty:=nullif(v_item->>'quantity','')::numeric;
   if v_med is null or v_qty is null or v_qty<=0 or v_qty>100000 then raise exception 'Each sale item needs a medicine and positive quantity'; end if;
   select m.name,coalesce(m.tax_percent,0) into v_name,v_tax_percent from public.medications m where m.id=v_med and m.clinic_id=p_clinic_id and m.active=true;
   if v_name is null then raise exception 'Medicine not found or inactive in this clinic'; end if;
   if p_prescription_id is not null and not exists(select 1 from public.prescription_items pi where pi.prescription_id=p_prescription_id and pi.clinic_id=p_clinic_id and pi.medication_id=v_med) then raise exception 'Medicine is not listed on the selected prescription'; end if;
   if p_prescription_id is not null and exists(select 1 from public.prescription_items pi where pi.prescription_id=p_prescription_id and pi.clinic_id=p_clinic_id and pi.medication_id=v_med and pi.quantity is not null and pi.quantity < (select sum((x.value->>'quantity')::numeric) from jsonb_array_elements(p_items) x(value) where nullif(x.value->>'medication_id','')::uuid=v_med)) then raise exception 'Requested quantity exceeds the quantity on the prescription'; end if;
   v_left:=v_qty; v_price:=null;
   for v_batch in select b.id,b.quantity_on_hand,b.sale_rate,b.expiry_date from public.inventory_batches b where b.clinic_id=p_clinic_id and b.medication_id=v_med and b.quantity_on_hand>0 and (b.expiry_date is null or b.expiry_date>=current_date) order by b.expiry_date asc nulls last,b.received_at asc for update loop
     exit when v_left<=0;
     v_take:=least(v_left,v_batch.quantity_on_hand); v_price:=coalesce(v_price,v_batch.sale_rate);
     update public.inventory_batches set quantity_on_hand=quantity_on_hand-v_take where id=v_batch.id and clinic_id=p_clinic_id;
     insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch.id,'dispense',v_take,'pharmacy_invoice',v_invoice,'Dispensed for invoice '||v_invoice_no,v_user);
     v_left:=v_left-v_take;
   end loop;
   if v_left>0 then raise exception 'Insufficient unexpired stock for % (short by %)',v_name,v_left; end if;
   v_price:=coalesce(nullif(v_item->>'unit_price','')::numeric,v_price,0);
   if v_price<0 or v_price>100000000 then raise exception 'Invalid sale price'; end if;
   v_line:=round(v_qty*v_price,2); v_line_tax:=round(v_line*coalesce(v_tax_percent,0)/100,2); v_line_total:=v_line+v_line_tax; v_subtotal:=v_subtotal+v_line; v_tax:=v_tax+v_line_tax; v_total:=v_total+v_line_total; v_count:=v_count+1;
   insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,tax_percent,line_total) values(p_clinic_id,v_invoice,'pharmacy',v_name,v_qty,v_price,coalesce(v_tax_percent,0),v_line_total);
 end loop;
 if v_count=0 or v_total<=0 then raise exception 'Pharmacy invoice total must be greater than zero'; end if;
 v_paid:=case when coalesce(p_collect_now,false) then v_total else 0 end; v_status:=case when v_paid=v_total then 'paid' else 'issued' end;
 update public.invoices set status=v_status,subtotal=v_subtotal,tax_amount=v_tax,total_amount=v_total,paid_amount=v_paid,updated_at=now() where id=v_invoice and clinic_id=p_clinic_id;
 if v_paid>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at) values(p_clinic_id,v_invoice,p_patient_id,v_paid,p_payment_method,'completed',v_user,now()); end if;
 if p_prescription_id is not null then update public.prescriptions set status='dispensed' where id=p_prescription_id and clinic_id=p_clinic_id; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'dispense_pharmacy_sale','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_invoice_no,'patient_id',p_patient_id,'prescription_id',p_prescription_id,'subtotal',v_subtotal,'tax_amount',v_tax,'total',v_total,'paid',v_paid,'items',v_count));
 return jsonb_build_object('id',v_invoice,'invoice_no',v_invoice_no,'patient_id',p_patient_id,'prescription_id',p_prescription_id,'subtotal',v_subtotal,'tax_amount',v_tax,'total_amount',v_total,'paid_amount',v_paid,'status',v_status,'item_count',v_count);
end $$;
revoke all on function public.dispense_pharmacy_sale(uuid,uuid,jsonb,uuid,text,boolean) from public,anon;
grant execute on function public.dispense_pharmacy_sale(uuid,uuid,jsonb,uuid,text,boolean) to authenticated;

create index if not exists prescriptions_validity_idx on public.prescriptions(clinic_id,patient_id,valid_until desc);

-- Lab orders create a linked invoice so diagnostics are not left outside clinic billing.
create or replace function public.create_clinic_billed_lab_order(p_clinic_id uuid,p_patient_id uuid,p_lab_test_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_order jsonb; v_order_id uuid; v_test_name text; v_price numeric; v_invoice uuid; v_invoice_no text; v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','lab_technician']) then raise exception 'Laboratory-order permission required'; end if;
 select t.name,t.price into v_test_name,v_price from public.lab_tests t where t.id=p_lab_test_id and t.clinic_id=p_clinic_id and t.active=true;
 if v_test_name is null then raise exception 'Active lab test not found in this clinic'; end if;
 v_order:=public.create_clinic_lab_order(p_clinic_id,p_patient_id,p_lab_test_id); v_order_id:=(v_order->>'id')::uuid;
 v_invoice:=gen_random_uuid();v_invoice_no:='LAB-BILL-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
 values(v_invoice,p_clinic_id,p_patient_id,v_invoice_no,'issued',v_price,v_price,0,now(),v_user);
 insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total)
 values(p_clinic_id,v_invoice,'laboratory','Lab test: '||v_test_name,1,v_price,v_price);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_billed_lab_order','invoice',v_invoice::text,jsonb_build_object('lab_order_id',v_order_id,'test_name',v_test_name,'amount',v_price,'invoice_no',v_invoice_no));
 return v_order||jsonb_build_object('invoice_id',v_invoice,'invoice_no',v_invoice_no,'invoice_amount',v_price,'invoice_status','issued');
end $$;
revoke all on function public.create_clinic_billed_lab_order(uuid,uuid,uuid) from public,anon;
grant execute on function public.create_clinic_billed_lab_order(uuid,uuid,uuid) to authenticated;

create or replace function public.record_clinic_invoice_payment(p_clinic_id uuid,p_invoice_id uuid,p_amount numeric,p_method text default 'cash',p_reference text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_invoice public.invoices%rowtype; v_new_paid numeric; v_status text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','accountant','receptionist','pharmacist']) then raise exception 'Billing permission required'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Payment amount must be positive'; end if;
 if p_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 select * into v_invoice from public.invoices i where i.id=p_invoice_id and i.clinic_id=p_clinic_id for update;
 if v_invoice.id is null then raise exception 'Invoice not found in this clinic'; end if;
 if v_invoice.status in ('void','refunded') then raise exception 'Cannot pay a void/refunded invoice'; end if;
 if p_amount>v_invoice.total_amount-v_invoice.paid_amount then raise exception 'Payment exceeds outstanding balance'; end if;
 v_new_paid:=v_invoice.paid_amount+p_amount;v_status:=case when v_new_paid>=v_invoice.total_amount then 'paid' else 'part_paid' end;
 insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,transaction_reference,status,received_by,paid_at) values(p_clinic_id,p_invoice_id,v_invoice.patient_id,p_amount,p_method,nullif(trim(coalesce(p_reference,'')),''),'completed',v_user,now());
 update public.invoices set paid_amount=v_new_paid,status=v_status,updated_at=now() where id=p_invoice_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_invoice_payment','invoice',p_invoice_id::text,jsonb_build_object('amount',p_amount,'method',p_method,'paid_total',v_new_paid,'status',v_status));
 return jsonb_build_object('invoice_id',p_invoice_id,'paid_amount',v_new_paid,'balance_due',v_invoice.total_amount-v_new_paid,'status',v_status);
end $$;
revoke all on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) to authenticated;
