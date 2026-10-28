alter table public.invoices add column if not exists consolidated_into_invoice_id uuid references public.invoices(id) on delete set null;
create index if not exists invoices_consolidated_into_idx on public.invoices(clinic_id,consolidated_into_invoice_id);

-- Mark existing source invoices that are already represented in a final IPD invoice.
update public.invoices src
set consolidated_into_invoice_id = fin.id, updated_at=now()
from public.invoices fin
where fin.clinic_id=src.clinic_id
  and fin.admission_id=src.admission_id
  and fin.invoice_no like 'IPDF-%'
  and fin.status not in ('void','cancelled','refunded')
  and src.id<>fin.id
  and src.consolidated_into_invoice_id is null
  and src.invoice_no not like 'IPDF-%'
  and src.status not in ('void','cancelled','refunded')
  and (
    exists(select 1 from public.invoice_items fli where fli.clinic_id=fin.clinic_id and fli.invoice_id=fin.id and fli.description='Department invoice '||src.invoice_no)
    or (exists(select 1 from public.invoice_items fli where fli.clinic_id=fin.clinic_id and fli.invoice_id=fin.id and lower(fli.description) like '%bed%room%charge%')
        and exists(select 1 from public.invoice_items si where si.clinic_id=src.clinic_id and si.invoice_id=src.id and si.item_type in ('ipd','bed') and lower(si.description) like '%bed%charge%'))
  );

create or replace function public.record_clinic_invoice_payment(p_clinic_id uuid,p_invoice_id uuid,p_amount numeric,p_method text default 'cash',p_reference text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_invoice public.invoices%rowtype; v_new_paid numeric; v_status text; v_is_pharmacy_only boolean; v_has_pharmacy boolean; v_has_non_pharmacy boolean;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Payment amount must be positive'; end if;
 if p_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','accountant','receptionist','billing','pharmacist']) then raise exception 'Billing permission required'; end if;
 select * into v_invoice from public.invoices i where i.id=p_invoice_id and i.clinic_id=p_clinic_id for update;
 if v_invoice.id is null then raise exception 'Invoice not found in this clinic'; end if;
 if v_invoice.consolidated_into_invoice_id is not null then raise exception 'This invoice is already included in final IPD bill. Record payment against the final IPD invoice instead.'; end if;
 select exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=p_invoice_id and ii.item_type='pharmacy'),
        exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=p_invoice_id and ii.item_type<>'pharmacy')
 into v_has_pharmacy,v_has_non_pharmacy;
 v_is_pharmacy_only:=v_has_pharmacy and not v_has_non_pharmacy;
 if private.has_clinic_role(p_clinic_id,array['pharmacist']) and not v_is_pharmacy_only then raise exception 'Pharmacist can collect payment only for pharmacy-only invoices.'; end if;
 if v_invoice.status in ('void','refunded','cancelled') then raise exception 'Cannot pay a void/refunded/cancelled invoice'; end if;
 if p_amount>v_invoice.total_amount-v_invoice.paid_amount then raise exception 'Payment exceeds outstanding balance'; end if;
 v_new_paid:=round(v_invoice.paid_amount+p_amount,2); v_status:=case when v_new_paid>=v_invoice.total_amount then 'paid' else 'part_paid' end;
 insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,transaction_reference,status,received_by,paid_at)
 values(p_clinic_id,p_invoice_id,v_invoice.patient_id,p_amount,p_method,nullif(trim(coalesce(p_reference,'')),''),'completed',v_user,now());
 update public.invoices set paid_amount=v_new_paid,status=v_status,updated_at=now() where id=p_invoice_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_invoice_payment','invoice',p_invoice_id::text,jsonb_build_object('amount',p_amount,'method',p_method,'paid_total',v_new_paid,'status',v_status));
 return jsonb_build_object('invoice_id',p_invoice_id,'paid_amount',v_new_paid,'balance_due',greatest(0,v_invoice.total_amount-v_new_paid),'status',v_status);
end $$;
revoke all on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.finalize_ipd_bill(p_clinic_id uuid,p_admission_id uuid,p_payment_method text default 'cash')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid(); v_patient uuid; v_invoice uuid:=gen_random_uuid(); v_no text; v_total numeric:=0;
 v_advance numeric:=0; v_existing uuid; v_item_count int:=0; r record; v_apply numeric; v_has_bed_invoice boolean:=false;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','accountant']) then raise exception 'Final IPD billing permission required'; end if;
 if p_payment_method not in ('cash','upi','card','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred','discharged') for update;
 if v_patient is null then raise exception 'Admission not found in this clinic'; end if;
 select id into v_existing from public.invoices where clinic_id=p_clinic_id and admission_id=p_admission_id and invoice_no like 'IPDF-%' and status not in ('void','cancelled','refunded') order by created_at desc limit 1;
 if v_existing is not null then raise exception 'Final IPD bill already exists for this admission'; end if;
 select exists(select 1 from public.invoices i join public.invoice_items ii on ii.clinic_id=i.clinic_id and ii.invoice_id=i.id where i.clinic_id=p_clinic_id and i.admission_id=p_admission_id and i.invoice_no not like 'IPDF-%' and i.status not in ('void','cancelled','refunded') and ii.item_type in ('ipd','bed') and lower(ii.description) like '%bed%charge%') into v_has_bed_invoice;
 insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,v_patient,p_admission_id,'PENDING','issued',0,0,0,now(),v_user);
 v_no:='IPDF-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8)); update public.invoices set invoice_no=v_no where id=v_invoice;
 if not v_has_bed_invoice then
  insert into public.ipd_charge_entries(clinic_id,admission_id,patient_id,charge_type,description,quantity,unit_price,service_at,created_by)
  select p_clinic_id,a.id,a.patient_id,'bed','Bed / room charges (12-hour blocks)',greatest(1,ceil(extract(epoch from (coalesce(a.discharged_at,now())-a.admitted_at))/43200)),b.price_per_12_hours,a.admitted_at,v_user
  from public.admissions a join public.room_beds b on b.id=a.bed_id and b.clinic_id=a.clinic_id where a.id=p_admission_id and a.clinic_id=p_clinic_id and b.price_per_12_hours>0
   and not exists(select 1 from public.ipd_charge_entries x where x.clinic_id=p_clinic_id and x.admission_id=p_admission_id and x.charge_type='bed');
 end if;
 for r in select * from public.ipd_charge_entries x where x.clinic_id=p_clinic_id and x.admission_id=p_admission_id and x.billed_invoice_id is null and not (v_has_bed_invoice and x.charge_type='bed') order by x.service_at,x.id for update loop
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,r.charge_type,r.description,r.quantity,r.unit_price,r.amount);
  v_total:=v_total+r.amount; v_item_count:=v_item_count+1; update public.ipd_charge_entries set billed_invoice_id=v_invoice where id=r.id;
 end loop;
 if v_has_bed_invoice then update public.ipd_charge_entries set billed_invoice_id=v_invoice where clinic_id=p_clinic_id and admission_id=p_admission_id and charge_type='bed' and billed_invoice_id is null; end if;
 for r in select i.id,i.invoice_no,i.total_amount,i.paid_amount from public.invoices i
  where i.clinic_id=p_clinic_id and i.patient_id=v_patient and (i.admission_id is null or i.admission_id=p_admission_id) and i.id<>v_invoice and i.invoice_no not like 'IPDF-%'
   and i.consolidated_into_invoice_id is null and coalesce(i.paid_amount,0) < i.total_amount and i.status not in ('void','cancelled','refunded')
   and i.created_at >= (select admitted_at from public.admissions where id=p_admission_id) and i.created_at <= coalesce((select discharged_at from public.admissions where id=p_admission_id),now())
   and exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=i.id and ii.item_type in ('pharmacy','lab','laboratory','radiology','diagnostic','service','procedure','medicine','consumable','ipd','bed')) order by i.created_at for update loop
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,'service','Department invoice '||r.invoice_no,1,r.total_amount,r.total_amount);
  v_total:=v_total+r.total_amount; v_item_count:=v_item_count+1;
  if coalesce(r.paid_amount,0)>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at,notes) values(p_clinic_id,v_invoice,v_patient,least(r.paid_amount,r.total_amount),'other','completed',v_user,now(),'Payment carried forward from department invoice '||r.invoice_no); v_advance:=v_advance+least(r.paid_amount,r.total_amount); end if;
  update public.invoices set consolidated_into_invoice_id=v_invoice,updated_at=now() where id=r.id and clinic_id=p_clinic_id;
 end loop;
 update public.invoices set subtotal=round(v_total,2),total_amount=round(v_total,2),updated_at=now() where id=v_invoice;
 for r in select * from public.ipd_advance_receipts where clinic_id=p_clinic_id and admission_id=p_admission_id and applied_amount<amount order by received_at,id for update loop
  exit when v_total-v_advance<=0; v_apply:=least(r.amount-r.applied_amount,v_total-v_advance);
  if v_apply>0 then update public.ipd_advance_receipts set applied_amount=applied_amount+v_apply where id=r.id;
   insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,transaction_reference,received_by,paid_at,notes) values(p_clinic_id,v_invoice,v_patient,v_apply,r.method,'completed',r.reference,r.received_by,r.received_at,'Applied advance receipt '||r.receipt_no); v_advance:=v_advance+v_apply; end if;
 end loop;
 update public.invoices set paid_amount=least(v_total,v_advance),status=case when v_total>0 and v_advance>=v_total then 'paid' when v_advance>0 then 'part_paid' else 'issued' end,updated_at=now() where id=v_invoice;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'finalize_ipd_bill','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_no,'admission_id',p_admission_id,'total',v_total,'advance_applied',v_advance,'line_items',v_item_count));
 return jsonb_build_object('id',v_invoice,'invoice_no',v_no,'admission_id',p_admission_id,'total_amount',round(v_total,2),'advance_applied',round(v_advance,2),'balance_due',round(greatest(0,v_total-v_advance),2),'line_items',v_item_count);
end $$;
revoke all on function public.finalize_ipd_bill(uuid,uuid,text) from public,anon;
grant execute on function public.finalize_ipd_bill(uuid,uuid,text) to authenticated;
