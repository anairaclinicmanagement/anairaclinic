-- Reception creates one invoice for selected diagnostics; each test is routed to its own department queue.
alter table public.lab_orders add column if not exists invoice_id uuid references public.invoices(id) on delete set null;
alter table public.lab_orders add column if not exists department_key text not null default 'laboratory';
create index if not exists lab_orders_clinic_department_invoice_idx on public.lab_orders(clinic_id,department_key,invoice_id,ordered_at desc);

create or replace function public.create_reception_diagnostic_bill(p_clinic_id uuid,p_patient_id uuid,p_test_ids uuid[],p_payment_method text default 'cash',p_collect_now boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); v_invoice uuid:=gen_random_uuid(); v_invoice_no text; v_total numeric:=0; v_paid numeric:=0; v_count int:=0; t record; v_status text; v_order uuid; v_order_no text; v_dept text; v_orders jsonb:='[]'::jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist']) then raise exception 'Reception billing permission required'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 if p_test_ids is null or cardinality(p_test_ids)=0 or cardinality(p_test_ids)>50 then raise exception 'Select between 1 and 50 tests'; end if;
 if cardinality(p_test_ids)<>(select count(distinct x) from unnest(p_test_ids) x) then raise exception 'Duplicate test selection'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 for t in select id,name,category,price,reference_range from public.lab_tests where clinic_id=p_clinic_id and active=true and id=any(p_test_ids) loop v_total:=v_total+t.price; v_count:=v_count+1; end loop;
 if v_count<>cardinality(p_test_ids) then raise exception 'One or more selected tests are inactive or do not belong to this clinic'; end if;
 if v_total<=0 then raise exception 'Diagnostic bill total must be greater than zero'; end if;
 v_invoice_no:='DIA-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 v_paid:=case when coalesce(p_collect_now,false) then v_total else 0 end; v_status:=case when v_paid>=v_total then 'paid' else 'issued' end;
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,p_patient_id,v_invoice_no,v_status,v_total,v_total,v_paid,now(),u);
 for t in select id,name,category,price,reference_range from public.lab_tests where clinic_id=p_clinic_id and active=true and id=any(p_test_ids) order by category,name loop
  v_dept:=case when lower(coalesce(t.category,'')) like '%x-ray%' or lower(coalesce(t.category,'')) like '%xray%' then 'xray' when lower(coalesce(t.category,'')) like '%ultrasound%' or lower(coalesce(t.category,'')) like '%usg%' then 'ultrasound' when lower(coalesce(t.category,'')) like '%ct%' or lower(coalesce(t.category,'')) like '%mri%' then 'ct_mri' when lower(coalesce(t.category,'')) like '%radiology%' or lower(coalesce(t.category,'')) like '%imaging%' then 'radiology' else 'laboratory' end;
  v_order:=gen_random_uuid(); v_order_no:='DX-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_order::text,'-',''),1,8));
  insert into public.lab_orders(id,clinic_id,patient_id,ordered_by,order_no,status,ordered_at,invoice_id,department_key,notes) values(v_order,p_clinic_id,p_patient_id,(select id from public.staff_profiles where clinic_id=p_clinic_id and user_id=u limit 1),v_order_no,'ordered',now(),v_invoice,v_dept,'Reception diagnostic bill '||v_invoice_no);
  insert into public.lab_order_items(clinic_id,lab_order_id,lab_test_id,test_name,category,status,reference_range) values(p_clinic_id,v_order,t.id,t.name,coalesce(nullif(trim(t.category),''),'Laboratory'),'pending',t.reference_range);
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,'laboratory',coalesce(nullif(trim(t.category),''),'Laboratory')||': '||t.name,1,t.price,t.price);
  v_orders:=v_orders||jsonb_build_array(jsonb_build_object('order_id',v_order,'order_no',v_order_no,'test_name',t.name,'category',t.category,'department_key',v_dept,'price',t.price));
 end loop;
 if v_paid>0 then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at) values(p_clinic_id,v_invoice,p_patient_id,v_paid,p_payment_method,'completed',u,now()); end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'create_reception_diagnostic_bill','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_invoice_no,'total',v_total,'paid',v_paid,'test_count',v_count,'orders',v_orders));
 return jsonb_build_object('invoice_id',v_invoice,'invoice_no',v_invoice_no,'total_amount',v_total,'paid_amount',v_paid,'status',v_status,'test_count',v_count,'orders',v_orders,'released_to_departments',v_status='paid');
end $$;
revoke all on function public.create_reception_diagnostic_bill(uuid,uuid,uuid[],text,boolean) from public,anon;
grant execute on function public.create_reception_diagnostic_bill(uuid,uuid,uuid[],text,boolean) to authenticated;

create or replace function public.update_clinic_diagnostic_item(p_clinic_id uuid,p_item_id uuid,p_status text,p_result_text text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); v_order public.lab_orders%rowtype; v_item public.lab_order_items%rowtype; v_role text; v_invoice_status text; v_order_status text;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if p_status not in ('processing','completed') then raise exception 'Unsupported diagnostic status'; end if;
 select role into v_role from public.clinic_members where clinic_id=p_clinic_id and user_id=u and active=true limit 1;
 if v_role is null then raise exception 'Active clinic membership required'; end if;
 select * into v_item from public.lab_order_items where id=p_item_id and clinic_id=p_clinic_id for update; if v_item.id is null then raise exception 'Diagnostic test not found'; end if;
 select * into v_order from public.lab_orders where id=v_item.lab_order_id and clinic_id=p_clinic_id for update; if v_order.id is null then raise exception 'Diagnostic order not found'; end if;
 select status into v_invoice_status from public.invoices where id=v_order.invoice_id and clinic_id=p_clinic_id; if v_invoice_status is distinct from 'paid' then raise exception 'Reception payment must be completed before the department can process this test'; end if;
 if v_role not in ('owner','admin') then
  if v_order.department_key='laboratory' and v_role<>'lab_technician' then raise exception 'Laboratory technician role required';
  elsif v_order.department_key='xray' and v_role not in ('radiology_technician','xray_technician') then raise exception 'X-Ray technician role required';
  elsif v_order.department_key='ultrasound' and v_role not in ('radiology_technician','ultrasound_technician') then raise exception 'Ultrasound technician role required';
  elsif v_order.department_key='ct_mri' and v_role not in ('radiology_technician','ct_mri_technician') then raise exception 'CT/MRI technician role required';
  elsif v_order.department_key='radiology' and v_role not in ('radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician') then raise exception 'Imaging technician role required'; end if;
 end if;
 if p_status='completed' and coalesce(trim(p_result_text),'')='' then raise exception 'Enter the result/report before completing the test'; end if;
 update public.lab_order_items set status=p_status,result_text=case when p_status='completed' then trim(p_result_text) else result_text end,reported_by=case when p_status='completed' then u else reported_by end,reported_at=case when p_status='completed' then now() else reported_at end where id=p_item_id and clinic_id=p_clinic_id;
 if not exists(select 1 from public.lab_order_items i where i.lab_order_id=v_order.id and i.clinic_id=p_clinic_id and i.status not in ('completed','cancelled')) then v_order_status:='completed'; update public.lab_orders set status='completed',completed_at=now() where id=v_order.id and clinic_id=p_clinic_id; else v_order_status:='processing'; update public.lab_orders set status='processing' where id=v_order.id and clinic_id=p_clinic_id; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'update_diagnostic_test_status','lab_order_item',p_item_id::text,jsonb_build_object('order_id',v_order.id,'department_key',v_order.department_key,'status',p_status));
 return jsonb_build_object('item_id',p_item_id,'order_id',v_order.id,'item_status',p_status,'order_status',v_order_status);
end $$;
revoke all on function public.update_clinic_diagnostic_item(uuid,uuid,text,text) from public,anon;
grant execute on function public.update_clinic_diagnostic_item(uuid,uuid,text,text) to authenticated;

-- Restrictive module policies permit department-specific worklists while preserving tenant/role policies.
drop policy if exists lab_orders_module_entitlement on public.lab_orders;
create policy lab_orders_module_entitlement on public.lab_orders as restrictive for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']) or (department_key='laboratory' and clinic_module_access(clinic_id,'laboratory')) or (department_key in ('xray','ultrasound','ct_mri','radiology') and clinic_module_access(clinic_id,'radiology'))) with check (private.has_clinic_role(clinic_id,array['owner','admin']) or (department_key='laboratory' and clinic_module_access(clinic_id,'laboratory')) or (department_key in ('xray','ultrasound','ct_mri','radiology') and clinic_module_access(clinic_id,'radiology')));
drop policy if exists lab_order_items_module_entitlement on public.lab_order_items;
create policy lab_order_items_module_entitlement on public.lab_order_items as restrictive for all to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin']) or (exists(select 1 from public.lab_orders o where o.id=lab_order_items.lab_order_id and o.clinic_id=lab_order_items.clinic_id and o.department_key='laboratory') and clinic_module_access(clinic_id,'laboratory')) or (exists(select 1 from public.lab_orders o where o.id=lab_order_items.lab_order_id and o.clinic_id=lab_order_items.clinic_id and o.department_key in ('xray','ultrasound','ct_mri','radiology')) and clinic_module_access(clinic_id,'radiology'))) with check (private.has_clinic_role(clinic_id,array['owner','admin']) or (exists(select 1 from public.lab_orders o where o.id=lab_order_items.lab_order_id and o.clinic_id=lab_order_items.clinic_id and o.department_key='laboratory') and clinic_module_access(clinic_id,'laboratory')) or (exists(select 1 from public.lab_orders o where o.id=lab_order_items.lab_order_id and o.clinic_id=lab_order_items.clinic_id and o.department_key in ('xray','ultrasound','ct_mri','radiology')) and clinic_module_access(clinic_id,'radiology')));

create or replace function public.clinic_patient_directory(p_clinic_id uuid)
returns table(id uuid,clinic_id uuid,uhid text,first_name text,middle_name text,last_name text,phone text,gender text,date_of_birth date,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','receptionist','nurse','pharmacist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']) then raise exception 'Patient directory access denied'; end if;
 return query select p.id,p.clinic_id,p.uhid,p.first_name,p.middle_name,p.last_name,p.phone,p.gender,p.date_of_birth,p.created_at from public.patients p where p.clinic_id=p_clinic_id and p.archived_at is null order by p.first_name,p.last_name limit 1000;
end $$;
revoke all on function public.clinic_patient_directory(uuid) from public,anon;
grant execute on function public.clinic_patient_directory(uuid) to authenticated;
