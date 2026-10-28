-- Admission-scoped charge capture, advance receipt, doctor round, pharmacy linkage and final billing.
create or replace function public.record_ipd_charge(p_clinic_id uuid,p_admission_id uuid,p_charge_type text,p_description text,p_quantity numeric,p_unit_price numeric,p_provider_name text default null,p_service_at timestamptz default now()) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_id uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant','pharmacist']) then raise exception 'IPD charge permission required'; end if;
 if p_charge_type not in ('bed','doctor_round','nursing','procedure','lab','radiology','medicine','consumable','service','other') then raise exception 'Invalid charge category'; end if;
 if coalesce(length(trim(p_description)),0)<2 or p_quantity is null or p_quantity<=0 or p_unit_price is null or p_unit_price<0 then raise exception 'Enter valid charge details'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred') for update;
 if v_patient is null then raise exception 'Active admission not found'; end if;
 insert into public.ipd_charge_entries(clinic_id,admission_id,patient_id,charge_type,description,provider_name,quantity,unit_price,service_at,created_by) values(p_clinic_id,p_admission_id,v_patient,p_charge_type,trim(p_description),nullif(trim(coalesce(p_provider_name,'')),''),p_quantity,p_unit_price,coalesce(p_service_at,now()),v_user) returning id into v_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_ipd_charge','ipd_charge',v_id::text,jsonb_build_object('admission_id',p_admission_id,'charge_type',p_charge_type,'amount',round(p_quantity*p_unit_price,2)));
 return jsonb_build_object('id',v_id,'admission_id',p_admission_id,'patient_id',v_patient,'amount',round(p_quantity*p_unit_price,2));
end $$;
revoke all on function public.record_ipd_charge(uuid,uuid,text,text,numeric,numeric,text,timestamptz) from public,anon;
grant execute on function public.record_ipd_charge(uuid,uuid,text,text,numeric,numeric,text,timestamptz) to authenticated;

create or replace function public.record_ipd_advance(p_clinic_id uuid,p_admission_id uuid,p_amount numeric,p_method text,p_reference text default null,p_notes text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_id uuid:=gen_random_uuid(); v_no text; v_now timestamptz:=now();
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','accountant']) then raise exception 'IPD advance receipt permission required'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Advance amount must be greater than zero'; end if;
 if p_method not in ('cash','upi','card','bank_transfer','other') then raise exception 'Unsupported payment method'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred') for update;
 if v_patient is null then raise exception 'Active admission not found'; end if;
 v_no:='ADV-'||to_char(v_now at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_id::text,'-',''),1,8));
 insert into public.ipd_advance_receipts(id,clinic_id,admission_id,patient_id,receipt_no,amount,method,reference,notes,received_by,received_at) values(v_id,p_clinic_id,p_admission_id,v_patient,v_no,round(p_amount,2),p_method,nullif(trim(coalesce(p_reference,'')),''),nullif(trim(coalesce(p_notes,'')),''),v_user,v_now);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_ipd_advance','ipd_advance_receipt',v_id::text,jsonb_build_object('receipt_no',v_no,'admission_id',p_admission_id,'amount',round(p_amount,2),'method',p_method));
 return jsonb_build_object('id',v_id,'receipt_no',v_no,'admission_id',p_admission_id,'patient_id',v_patient,'amount',round(p_amount,2),'received_at',v_now);
end $$;
revoke all on function public.record_ipd_advance(uuid,uuid,numeric,text,text,text) from public,anon;
grant execute on function public.record_ipd_advance(uuid,uuid,numeric,text,text,text) to authenticated;

create or replace function public.record_ipd_doctor_round(p_clinic_id uuid,p_admission_id uuid,p_doctor_name text,p_notes text,p_charge numeric,p_round_at timestamptz default now()) returns jsonb language plpgsql security definer set search_path='' as $$ declare v_result jsonb; begin if coalesce(length(trim(p_doctor_name)),0)<2 then raise exception 'Doctor name is required'; end if; v_result:=public.record_ipd_charge(p_clinic_id,p_admission_id,'doctor_round','Doctor round / visit - '||trim(p_doctor_name),1,greatest(0,coalesce(p_charge,0)),p_doctor_name,coalesce(p_round_at,now())); update public.ipd_charge_entries set description=case when coalesce(trim(p_notes),'')='' then description else description||' · '||left(trim(p_notes),200) end where id=(v_result->>'id')::uuid and clinic_id=p_clinic_id; return v_result||jsonb_build_object('doctor_name',trim(p_doctor_name),'round_at',coalesce(p_round_at,now())); end $$;
revoke all on function public.record_ipd_doctor_round(uuid,uuid,text,text,numeric,timestamptz) from public,anon;
grant execute on function public.record_ipd_doctor_round(uuid,uuid,text,text,numeric,timestamptz) to authenticated;

create or replace function public.dispense_pharmacy_sale_for_admission(p_clinic_id uuid,p_patient_id uuid,p_admission_id uuid,p_items jsonb,p_prescription_id uuid default null,p_payment_method text default 'cash',p_collect_now boolean default true,p_discount_type text default 'percent',p_discount_value numeric default 0,p_discount_reason text default null) returns jsonb language plpgsql security definer set search_path='' as $$ declare v_result jsonb; begin if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Pharmacy billing permission required'; end if; if p_admission_id is not null and not exists(select 1 from public.admissions a where a.id=p_admission_id and a.clinic_id=p_clinic_id and a.patient_id=p_patient_id and a.status in ('admitted','transferred')) then raise exception 'Selected IPD admission does not match this patient or is no longer active'; end if; v_result:=public.dispense_pharmacy_sale_discounted(p_clinic_id,p_patient_id,p_items,p_prescription_id,p_payment_method,p_collect_now,p_discount_type,p_discount_value,p_discount_reason); if p_admission_id is not null then update public.invoices set admission_id=p_admission_id,updated_at=now() where id=(v_result->>'id')::uuid and clinic_id=p_clinic_id and patient_id=p_patient_id; end if; return v_result||jsonb_build_object('admission_id',p_admission_id); end $$;
revoke all on function public.dispense_pharmacy_sale_for_admission(uuid,uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text) from public,anon;
grant execute on function public.dispense_pharmacy_sale_for_admission(uuid,uuid,uuid,jsonb,uuid,text,boolean,text,numeric,text) to authenticated;

-- Final invoice collects unbilled ledger items, linked department invoices and available advances.
-- See the connected project's migration named ipd_final_invoice_payment_and_source_reconcile for the full deployed definition,
-- including date-window reconciliation, automatic 12-hour bed charge calculation and oldest-first advance allocation.

create or replace function public.finalize_ipd_bill(p_clinic_id uuid,p_admission_id uuid,p_payment_method text default 'cash') returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_invoice uuid:=gen_random_uuid(); v_no text; v_total numeric:=0; v_advance numeric:=0; v_existing uuid; v_item_count int:=0; r record; v_apply numeric;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','accountant']) then raise exception 'Final IPD billing permission required'; end if;
 if p_payment_method not in ('cash','upi','card','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred','discharged') for update;
 if v_patient is null then raise exception 'Admission not found in this clinic'; end if;
 select id into v_existing from public.invoices where clinic_id=p_clinic_id and admission_id=p_admission_id and invoice_no like 'IPDF-%' and status not in ('void','cancelled','refunded') order by created_at desc limit 1;
 if v_existing is not null then raise exception 'Final IPD bill already exists for this admission'; end if;
 insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,v_patient,p_admission_id,'PENDING','issued',0,0,0,now(),v_user);
 v_no:='IPDF-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8)); update public.invoices set invoice_no=v_no where id=v_invoice;
 insert into public.ipd_charge_entries(clinic_id,admission_id,patient_id,charge_type,description,quantity,unit_price,service_at,created_by)
 select p_clinic_id,a.id,a.patient_id,'bed','Bed / room charges (12-hour blocks)',greatest(1,ceil(extract(epoch from (coalesce(a.discharged_at,now())-a.admitted_at))/43200)),b.price_per_12_hours,a.admitted_at,v_user
 from public.admissions a join public.room_beds b on b.id=a.bed_id and b.clinic_id=a.clinic_id where a.id=p_admission_id and a.clinic_id=p_clinic_id and b.price_per_12_hours>0 and not exists(select 1 from public.ipd_charge_entries x where x.clinic_id=p_clinic_id and x.admission_id=p_admission_id and x.charge_type='bed');
 for r in select * from public.ipd_charge_entries where clinic_id=p_clinic_id and admission_id=p_admission_id and billed_invoice_id is null order by service_at,id for update loop
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,r.charge_type,r.description,r.quantity,r.unit_price,r.amount);
  v_total:=v_total+r.amount; v_item_count:=v_item_count+1; update public.ipd_charge_entries set billed_invoice_id=v_invoice where id=r.id;
 end loop;
 for r in select i.id,i.invoice_no,i.total_amount,i.paid_amount from public.invoices i where i.clinic_id=p_clinic_id and i.patient_id=v_patient and (i.admission_id is null or i.admission_id=p_admission_id) and i.id<>v_invoice and i.invoice_no not like 'IPDF-%' and i.status not in ('void','cancelled','refunded') and i.created_at >= (select admitted_at from public.admissions where id=p_admission_id) and i.created_at <= coalesce((select discharged_at from public.admissions where id=p_admission_id),now()) and exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=i.id and ii.item_type in ('pharmacy','lab','radiology','diagnostic','service','procedure','medicine','consumable')) order by i.created_at for update loop
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,'service','Department invoice '||r.invoice_no,1,r.total_amount,r.total_amount);
  v_total:=v_total+r.total_amount; v_item_count:=v_item_count+1; if coalesce(r.paid_amount,0)>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at,notes) values(p_clinic_id,v_invoice,v_patient,least(r.paid_amount,r.total_amount),'other','completed',v_user,now(),'Payment carried forward from department invoice '||r.invoice_no); v_advance:=v_advance+least(r.paid_amount,r.total_amount); end if; update public.invoices set admission_id=p_admission_id where id=r.id and admission_id is null;
 end loop;
 update public.invoices set subtotal=round(v_total,2),total_amount=round(v_total,2),updated_at=now() where id=v_invoice;
 for r in select * from public.ipd_advance_receipts where clinic_id=p_clinic_id and admission_id=p_admission_id and applied_amount<amount order by received_at,id for update loop
  exit when v_total-v_advance<=0; v_apply:=least(r.amount-r.applied_amount,v_total-v_advance);
  if v_apply>0 then update public.ipd_advance_receipts set applied_amount=applied_amount+v_apply where id=r.id;
   insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,transaction_reference,received_by,paid_at,notes) values(p_clinic_id,v_invoice,v_patient,v_apply,r.method,'completed',r.reference,r.received_by,r.received_at,'Applied advance receipt '||r.receipt_no); v_advance:=v_advance+v_apply;
  end if;
 end loop;
 update public.invoices set paid_amount=least(v_total,v_advance),status=case when v_total>0 and v_advance>=v_total then 'paid' when v_advance>0 then 'partially_paid' else 'issued' end,updated_at=now() where id=v_invoice;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'finalize_ipd_bill','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_no,'admission_id',p_admission_id,'total',v_total,'advance_applied',v_advance,'line_items',v_item_count));
 return jsonb_build_object('id',v_invoice,'invoice_no',v_no,'admission_id',p_admission_id,'total_amount',round(v_total,2),'advance_applied',round(v_advance,2),'balance_due',round(greatest(0,v_total-v_advance),2),'line_items',v_item_count);
end $$;
revoke all on function public.finalize_ipd_bill(uuid,uuid,text) from public,anon;
grant execute on function public.finalize_ipd_bill(uuid,uuid,text) to authenticated;
