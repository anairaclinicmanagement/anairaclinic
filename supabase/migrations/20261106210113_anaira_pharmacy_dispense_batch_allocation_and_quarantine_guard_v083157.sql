-- Pharmacy dispense now records exact batch allocations per invoice line and excludes non-saleable batches.
create or replace function public.dispense_pharmacy_sale(p_clinic_id uuid,p_patient_id uuid,p_items jsonb,p_prescription_id uuid default null,p_payment_method text default 'cash',p_collect_now boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid(); v_invoice uuid; v_invoice_no text; v_item jsonb; v_med uuid; v_qty numeric;
 v_left numeric; v_take numeric; v_batch record; v_name text; v_price numeric; v_tax_percent numeric;
 v_subtotal numeric:=0; v_tax numeric:=0; v_total numeric:=0; v_line_base numeric; v_line_tax numeric;
 v_line_gross numeric; v_count integer:=0; v_paid numeric:=0; v_status text; v_invoice_item uuid; v_allocations jsonb; v_alloc jsonb;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Pharmacist/clinic admin permission required'; end if;
 if not public.clinic_module_access(p_clinic_id,'pharmacy') then raise exception 'Pharmacy module is not enabled for this clinic'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100 then raise exception 'Add between 1 and 100 sale items'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 if p_prescription_id is not null and not exists(select 1 from public.prescriptions r where r.id=p_prescription_id and r.clinic_id=p_clinic_id and r.patient_id=p_patient_id and r.status in ('signed','dispensed') and coalesce(r.valid_until,r.prescribed_at::date+r.validity_days)>=current_date) then raise exception 'Prescription expired, cancelled or does not belong to this patient. Create a new prescription.'; end if;
 v_invoice:=gen_random_uuid(); v_invoice_no:='PH-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,tax_amount,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,p_patient_id,v_invoice_no,'draft',0,0,0,0,now(),v_user);
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_med:=nullif(v_item->>'medication_id','')::uuid; v_qty:=nullif(v_item->>'quantity','')::numeric;
  if v_med is null or v_qty is null or v_qty<=0 or v_qty>100000 then raise exception 'Each sale item needs a medicine and positive quantity'; end if;
  select m.name,m.tax_percent into v_name,v_tax_percent from public.medications m where m.id=v_med and m.clinic_id=p_clinic_id and m.active=true;
  if v_name is null then raise exception 'Medicine not found or inactive in this clinic'; end if;
  if p_prescription_id is not null and not exists(select 1 from public.prescription_items pi where pi.prescription_id=p_prescription_id and pi.clinic_id=p_clinic_id and pi.medication_id=v_med) then raise exception 'Medicine is not listed on the selected prescription'; end if;
  if p_prescription_id is not null and exists(select 1 from public.prescription_items pi where pi.prescription_id=p_prescription_id and pi.clinic_id=p_clinic_id and pi.medication_id=v_med and pi.quantity is not null and pi.quantity < (select sum((x.value->>'quantity')::numeric) from jsonb_array_elements(p_items) x(value) where nullif(x.value->>'medication_id','')::uuid=v_med)) then raise exception 'Requested quantity exceeds the quantity on the prescription'; end if;
  v_left:=v_qty; v_price:=null; v_allocations:='[]'::jsonb;
  for v_batch in select b.id,b.quantity_on_hand,b.sale_rate,b.expiry_date from public.inventory_batches b where b.clinic_id=p_clinic_id and b.medication_id=v_med and b.quantity_on_hand>0 and coalesce(b.stock_condition,'saleable')='saleable' and (b.expiry_date is null or b.expiry_date>=current_date) order by b.expiry_date asc nulls last,b.received_at asc for update loop
   exit when v_left<=0; v_take:=least(v_left,v_batch.quantity_on_hand); v_price:=coalesce(v_price,v_batch.sale_rate);
   update public.inventory_batches set quantity_on_hand=quantity_on_hand-v_take where id=v_batch.id and clinic_id=p_clinic_id;
   insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch.id,'dispense',v_take,'pharmacy_invoice',v_invoice,'Dispensed for invoice '||v_invoice_no,v_user);
   v_allocations:=v_allocations||jsonb_build_array(jsonb_build_object('batch_id',v_batch.id,'quantity',v_take)); v_left:=v_left-v_take;
  end loop;
  if v_left>0 then raise exception 'Insufficient unexpired saleable stock for % (short by %)',v_name,v_left; end if;
  v_price:=coalesce(nullif(v_item->>'unit_price','')::numeric,v_price,0); if v_price<0 or v_price>100000000 then raise exception 'Invalid sale price'; end if;
  v_line_base:=round(v_qty*v_price,2); v_line_tax:=round(v_line_base*coalesce(v_tax_percent,0)/100,2); v_line_gross:=v_line_base+v_line_tax;
  v_subtotal:=v_subtotal+v_line_base; v_tax:=v_tax+v_line_tax; v_total:=v_total+v_line_gross; v_count:=v_count+1;
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,discount_amount,tax_percent,line_total) values(p_clinic_id,v_invoice,'pharmacy',v_name,v_qty,v_price,0,coalesce(v_tax_percent,0),v_line_gross) returning id into v_invoice_item;
  for v_alloc in select value from jsonb_array_elements(v_allocations) loop
   insert into public.pharmacy_dispense_allocations(clinic_id,invoice_id,invoice_item_id,batch_id,medication_id,dispensed_quantity) values(p_clinic_id,v_invoice,v_invoice_item,(v_alloc->>'batch_id')::uuid,v_med,(v_alloc->>'quantity')::numeric);
  end loop;
 end loop;
 if v_count=0 or v_total<=0 then raise exception 'Pharmacy invoice total must be greater than zero'; end if;
 v_paid:=case when coalesce(p_collect_now,false) then v_total else 0 end; v_status:=case when v_paid=v_total then 'paid' else 'issued' end;
 update public.invoices set status=v_status,subtotal=v_subtotal,tax_amount=v_tax,total_amount=v_total,paid_amount=v_paid,updated_at=now() where id=v_invoice and clinic_id=p_clinic_id;
 if v_paid>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at) values(p_clinic_id,v_invoice,p_patient_id,v_paid,p_payment_method,'completed',v_user,now()); end if;
 if p_prescription_id is not null then update public.prescriptions set status='dispensed' where id=p_prescription_id and clinic_id=p_clinic_id; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'dispense_pharmacy_sale','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_invoice_no,'patient_id',p_patient_id,'prescription_id',p_prescription_id,'subtotal',v_subtotal,'tax',v_tax,'total',v_total,'paid',v_paid,'items',v_count,'batch_allocations',true));
 return jsonb_build_object('id',v_invoice,'invoice_no',v_invoice_no,'patient_id',p_patient_id,'prescription_id',p_prescription_id,'subtotal',v_subtotal,'tax_amount',v_tax,'total_amount',v_total,'paid_amount',v_paid,'status',v_status,'item_count',v_count);
end $$;
