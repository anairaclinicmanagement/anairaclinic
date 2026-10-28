-- Reception can bill tests against an active IPD admission and collect later.
-- IPD diagnostic orders remain available to the appropriate department while the invoice is outstanding.
create or replace function public.create_ipd_reception_diagnostic_bill_discounted(
 p_clinic_id uuid,
 p_admission_id uuid,
 p_test_ids uuid[],
 p_payment_method text default 'cash',
 p_collect_now boolean default true,
 p_discount_type text default 'percent',
 p_discount_value numeric default 0,
 p_discount_reason text default null
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); v_patient uuid; v_admission_no text; v_invoice uuid:=gen_random_uuid(); v_invoice_no text;
 v_total numeric:=0; v_discount numeric:=0; v_final numeric:=0; v_paid numeric:=0; v_count int:=0;
 t record; v_order uuid; v_order_no text; v_dept text; v_orders jsonb:='[]'::jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','billing','accountant']) then raise exception 'Reception/Billing permission required'; end if;
 select a.patient_id,a.admission_no into v_patient,v_admission_no from public.admissions a
 where a.id=p_admission_id and a.clinic_id=p_clinic_id and a.status in ('admitted','transferred');
 if v_patient is null then raise exception 'Select an active IPD admission in this clinic'; end if;
 if p_discount_type not in ('percent','amount') then raise exception 'Invalid discount type'; end if;
 if coalesce(p_discount_value,0)<0 or (p_discount_type='percent' and p_discount_value>100) then raise exception 'Discount must be 0–100 percent or a non-negative amount'; end if;
 if length(coalesce(p_discount_reason,''))>160 then raise exception 'Discount reason is too long'; end if;
 if p_test_ids is null or cardinality(p_test_ids)=0 then raise exception 'Select at least one diagnostic test'; end if;
 if cardinality(p_test_ids)>50 then raise exception 'Select no more than 50 tests per bill'; end if;
 if cardinality(p_test_ids)<>(select count(distinct x) from unnest(p_test_ids) x) then raise exception 'Duplicate test selection'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 for t in select lt.id,lt.name,lt.category,lt.price,lt.reference_range from public.lab_tests lt where lt.clinic_id=p_clinic_id and lt.active=true and lt.id=any(p_test_ids) loop
   v_total:=v_total+t.price; v_count:=v_count+1;
 end loop;
 if v_count<>cardinality(p_test_ids) then raise exception 'One or more selected tests are inactive or do not belong to this clinic'; end if;
 if v_total<=0 then raise exception 'Diagnostic bill total must be greater than zero'; end if;
 v_discount:=case when p_discount_type='percent' then round(v_total*coalesce(p_discount_value,0)/100,2) else least(v_total,round(coalesce(p_discount_value,0),2)) end;
 v_discount:=least(v_total,v_discount); v_final:=round(v_total-v_discount,2);
 if v_final<=0 then raise exception 'Discount cannot reduce a diagnostic bill to zero'; end if;
 v_paid:=case when coalesce(p_collect_now,false) then v_final else 0 end;
 v_invoice_no:='IPDD-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
 values(v_invoice,p_clinic_id,v_patient,p_admission_id,v_invoice_no,case when v_paid>=v_final then 'paid' else 'issued' end,v_final,v_final,v_paid,now(),u);
 for t in select lt.id,lt.name,lt.category,lt.price,lt.reference_range from public.lab_tests lt where lt.clinic_id=p_clinic_id and lt.active=true and lt.id=any(p_test_ids) order by lt.category,lt.name loop
   v_dept:=case when lower(coalesce(t.category,'')) like '%x-ray%' or lower(coalesce(t.category,'')) like '%xray%' then 'xray'
    when lower(coalesce(t.category,'')) like '%ultrasound%' or lower(coalesce(t.category,'')) like '%usg%' then 'ultrasound'
    when lower(coalesce(t.category,'')) like '%ct%' or lower(coalesce(t.category,'')) like '%mri%' then 'ct_mri'
    when lower(coalesce(t.category,'')) like '%radiology%' or lower(coalesce(t.category,'')) like '%imaging%' or lower(coalesce(t.category,'')) like '%ecg%' or lower(coalesce(t.category,'')) like '%echo%' then 'radiology' else 'laboratory' end;
   v_order:=gen_random_uuid(); v_order_no:='DX-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_order::text,'-',''),1,8));
   insert into public.lab_orders(id,clinic_id,patient_id,admission_id,ordered_by,order_no,status,ordered_at,invoice_id,department_key,notes)
   values(v_order,p_clinic_id,v_patient,p_admission_id,(select sp.id from public.staff_profiles sp where sp.clinic_id=p_clinic_id and sp.user_id=u limit 1),v_order_no,'ordered',now(),v_invoice,v_dept,'IPD diagnostic bill '||v_invoice_no||' · Admission '||v_admission_no);
   insert into public.lab_order_items(clinic_id,lab_order_id,lab_test_id,test_name,category,status,reference_range)
   values(p_clinic_id,v_order,t.id,t.name,coalesce(nullif(trim(t.category),''),'Laboratory'),'pending',t.reference_range);
   insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,discount_amount,line_total)
   values(p_clinic_id,v_invoice,'laboratory',coalesce(nullif(trim(t.category),''),'Laboratory')||': '||t.name,1,t.price,round(t.price*v_discount/nullif(v_total,0),2),round(t.price-(t.price*v_discount/nullif(v_total,0)),2));
   v_orders:=v_orders||jsonb_build_array(jsonb_build_object('order_id',v_order,'order_no',v_order_no,'test_name',t.name,'category',t.category,'department_key',v_dept,'price',t.price));
 end loop;
 if v_paid>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at,notes)
   values(p_clinic_id,v_invoice,v_patient,v_paid,p_payment_method,'completed',u,now(),'IPD diagnostic bill payment'); end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,u,'create_ipd_reception_diagnostic_bill','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_invoice_no,'admission_id',p_admission_id,'admission_no',v_admission_no,'total',v_final,'paid',v_paid,'discount',v_discount,'test_count',v_count,'orders',v_orders));
 return jsonb_build_object('invoice_id',v_invoice,'invoice_no',v_invoice_no,'patient_id',v_patient,'admission_id',p_admission_id,'admission_no',v_admission_no,'total_amount',v_final,'original_total',v_total,'discount_amount',v_discount,'discount_type',p_discount_type,'discount_value',p_discount_value,'discount_reason',p_discount_reason,'paid_amount',v_paid,'status',case when v_paid>=v_final then 'paid' else 'issued' end,'test_count',v_count,'orders',v_orders,'released_to_departments',true,'payment_due',v_paid<v_final);
end $$;
revoke all on function public.create_ipd_reception_diagnostic_bill_discounted(uuid,uuid,uuid[],text,boolean,text,numeric,text) from public,anon;
grant execute on function public.create_ipd_reception_diagnostic_bill_discounted(uuid,uuid,uuid[],text,boolean,text,numeric,text) to authenticated;

-- Keep normal OPD worklists payment-gated. IPD orders are available on approved credit because the active admission is the clinical authorization.
drop policy if exists lab_orders_select_ipd_admission_credit on public.lab_orders;
create policy lab_orders_select_ipd_admission_credit on public.lab_orders for select to authenticated
using (
 admission_id is not null
 and private.has_clinic_role(clinic_id,array['lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician'])
 and exists(select 1 from public.admissions a where a.id=lab_orders.admission_id and a.clinic_id=lab_orders.clinic_id and a.patient_id=lab_orders.patient_id and a.status in ('admitted','transferred'))
 and exists(select 1 from public.invoices i where i.id=lab_orders.invoice_id and i.clinic_id=lab_orders.clinic_id and i.admission_id=lab_orders.admission_id and i.status not in ('void','cancelled','refunded'))
);
drop policy if exists lab_order_items_select_ipd_admission_credit on public.lab_order_items;
create policy lab_order_items_select_ipd_admission_credit on public.lab_order_items for select to authenticated
using (
 private.has_clinic_role(clinic_id,array['lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician'])
 and exists(select 1 from public.lab_orders o join public.admissions a on a.id=o.admission_id and a.clinic_id=o.clinic_id join public.invoices i on i.id=o.invoice_id and i.clinic_id=o.clinic_id and i.admission_id=o.admission_id
   where o.id=lab_order_items.lab_order_id and o.clinic_id=lab_order_items.clinic_id and a.patient_id=o.patient_id and a.status in ('admitted','transferred') and i.status not in ('void','cancelled','refunded'))
);
