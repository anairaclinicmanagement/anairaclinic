-- Atomic server-side workflows. These functions are SECURITY DEFINER and validate membership/role and clinic ownership.

create or replace function public.create_clinic_invoice(p_clinic_id uuid,p_patient_id uuid,p_description text,p_amount numeric,p_payment_method text default 'cash',p_collect_now boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_invoice_id uuid; v_invoice_no text; v_status text; v_method text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','accountant','receptionist']) then raise exception 'You do not have billing permission for this clinic'; end if;
 if coalesce(trim(p_description),'')='' then raise exception 'Invoice description is required'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Invoice amount is invalid'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 v_invoice_id:=gen_random_uuid(); v_invoice_no:='INV-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 v_status:=case when coalesce(p_collect_now,false) then 'paid' else 'issued' end; v_method:=coalesce(p_payment_method,'cash');
 insert into public.invoices(id,clinic_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice_id,p_clinic_id,p_patient_id,v_invoice_no,v_status,p_amount,p_amount,case when coalesce(p_collect_now,false) then p_amount else 0 end,now(),v_user);
 insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice_id,'service',trim(p_description),1,p_amount,p_amount);
 if coalesce(p_collect_now,false) then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at) values(p_clinic_id,v_invoice_id,p_patient_id,p_amount,v_method,'completed',v_user,now()); end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_invoice','invoice',v_invoice_id::text,jsonb_build_object('invoice_no',v_invoice_no,'amount',p_amount,'collected',coalesce(p_collect_now,false)));
 return jsonb_build_object('id',v_invoice_id,'invoice_no',v_invoice_no,'patient_id',p_patient_id,'total_amount',p_amount,'paid_amount',case when coalesce(p_collect_now,false) then p_amount else 0 end,'status',v_status,'created_at',now());
end $$;
revoke all on function public.create_clinic_invoice(uuid,uuid,text,numeric,text,boolean) from public,anon;
grant execute on function public.create_clinic_invoice(uuid,uuid,text,numeric,text,boolean) to authenticated;

create or replace function public.create_clinic_lab_order(p_clinic_id uuid,p_patient_id uuid,p_lab_test_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_order_id uuid; v_test_name text; v_test_code text; v_order_no text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','lab_technician']) then raise exception 'You do not have laboratory-order permission for this clinic'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 select t.name,t.test_code into v_test_name,v_test_code from public.lab_tests t where t.id=p_lab_test_id and t.clinic_id=p_clinic_id and t.active=true;
 if v_test_name is null then raise exception 'Active lab test not found in this clinic'; end if;
 v_order_id:=gen_random_uuid(); v_order_no:='LAB-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.lab_orders(id,clinic_id,patient_id,ordered_by,order_no,status,ordered_at) values(v_order_id,p_clinic_id,p_patient_id,null,v_order_no,'ordered',now());
 insert into public.lab_order_items(clinic_id,lab_order_id,lab_test_id,test_name,status) values(p_clinic_id,v_order_id,p_lab_test_id,v_test_name,'pending');
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_lab_order','lab_order',v_order_id::text,jsonb_build_object('order_no',v_order_no,'test_name',v_test_name,'test_code',v_test_code));
 return jsonb_build_object('id',v_order_id,'order_no',v_order_no,'patient_id',p_patient_id,'status','ordered','ordered_at',now(),'test_name',v_test_name);
end $$;
revoke all on function public.create_clinic_lab_order(uuid,uuid,uuid) from public,anon;
grant execute on function public.create_clinic_lab_order(uuid,uuid,uuid) to authenticated;

alter table public.encounters add column if not exists follow_up_at date;
create or replace function public.create_clinic_encounter(p_clinic_id uuid,p_patient_id uuid,p_chief_complaint text default null,p_history text default null,p_examination text default null,p_assessment text default null,p_plan text default null,p_follow_up date default null,p_vitals jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_encounter uuid; v_vitals jsonb:=coalesce(p_vitals,'{}'::jsonb); v_bp text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor']) then raise exception 'Doctor permission required'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 insert into public.encounters(clinic_id,patient_id,chief_complaint,history_of_present_illness,examination,assessment,plan,follow_up_at,status,started_at,created_by) values(p_clinic_id,p_patient_id,nullif(trim(coalesce(p_chief_complaint,'')),''),nullif(trim(coalesce(p_history,'')),''),nullif(trim(coalesce(p_examination,'')),''),nullif(trim(coalesce(p_assessment,'')),''),nullif(trim(coalesce(p_plan,'')),''),p_follow_up,'open',now(),v_user) returning id into v_encounter;
 v_bp:=nullif(trim(coalesce(v_vitals->>'blood_pressure','')),'');
 insert into public.vitals(clinic_id,encounter_id,patient_id,recorded_by,height_cm,weight_kg,temperature_c,pulse_bpm,systolic_bp,diastolic_bp,spo2,notes) values(p_clinic_id,v_encounter,p_patient_id,v_user,nullif(v_vitals->>'height_cm','')::numeric,nullif(v_vitals->>'weight_kg','')::numeric,nullif(v_vitals->>'temperature_c','')::numeric,nullif(v_vitals->>'pulse_bpm','')::integer,case when v_bp ~ '^[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*[0-9]+[[:space:]]*$' then split_part(regexp_replace(v_bp,'[[:space:]]','','g'),'/',1)::integer else null end,case when v_bp ~ '^[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*[0-9]+[[:space:]]*$' then split_part(regexp_replace(v_bp,'[[:space:]]','','g'),'/',2)::integer else null end,nullif(v_vitals->>'spo2','')::numeric,nullif(v_vitals->>'notes',''));
 if coalesce(trim(p_assessment),'')<>'' then insert into public.diagnoses(clinic_id,encounter_id,patient_id,label,is_primary,notes) values(p_clinic_id,v_encounter,p_patient_id,trim(p_assessment),true,nullif(trim(coalesce(p_plan,'')),'')); end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_encounter','encounter',v_encounter::text,jsonb_build_object('patient_id',p_patient_id,'follow_up_at',p_follow_up));
 return jsonb_build_object('id',v_encounter,'patient_id',p_patient_id,'status','open','started_at',now(),'follow_up_at',p_follow_up);
end $$;
revoke all on function public.create_clinic_encounter(uuid,uuid,text,text,text,text,text,date,jsonb) from public,anon;
grant execute on function public.create_clinic_encounter(uuid,uuid,text,text,text,text,text,date,jsonb) to authenticated;

create or replace function public.receive_pharmacy_stock(p_clinic_id uuid,p_medication_id uuid,p_batch_number text,p_quantity numeric,p_expiry_date date,p_purchase_rate numeric default 0,p_sale_rate numeric default 0,p_supplier_name text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_batch_id uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Pharmacy permission required'; end if;
 if p_quantity is null or p_quantity<=0 or p_quantity>10000000 then raise exception 'Quantity must be positive'; end if;
 if coalesce(trim(p_batch_number),'')='' then raise exception 'Batch number is required'; end if;
 if p_expiry_date is not null and p_expiry_date<current_date then raise exception 'Cannot receive an already expired batch'; end if;
 if p_purchase_rate<0 or p_sale_rate<0 then raise exception 'Rates cannot be negative'; end if;
 if not exists(select 1 from public.medications m where m.id=p_medication_id and m.clinic_id=p_clinic_id and m.active=true) then raise exception 'Active medicine not found in this clinic'; end if;
 select id into v_batch_id from public.inventory_batches where clinic_id=p_clinic_id and medication_id=p_medication_id and batch_number=trim(p_batch_number) for update;
 if v_batch_id is null then insert into public.inventory_batches(clinic_id,medication_id,batch_number,expiry_date,quantity_on_hand,purchase_rate,sale_rate,supplier_name,received_at) values(p_clinic_id,p_medication_id,trim(p_batch_number),p_expiry_date,p_quantity,coalesce(p_purchase_rate,0),coalesce(p_sale_rate,0),nullif(trim(coalesce(p_supplier_name,'')),''),now()) returning id into v_batch_id;
 else update public.inventory_batches set quantity_on_hand=quantity_on_hand+p_quantity,expiry_date=coalesce(p_expiry_date,expiry_date),purchase_rate=coalesce(p_purchase_rate,purchase_rate),sale_rate=coalesce(p_sale_rate,sale_rate),supplier_name=coalesce(nullif(trim(coalesce(p_supplier_name,'')),''),supplier_name) where id=v_batch_id; end if;
 insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by) values(p_clinic_id,v_batch_id,'purchase',p_quantity,'stock_receipt',v_batch_id,'Stock received: '||trim(p_batch_number),v_user);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'receive_pharmacy_stock','inventory_batch',v_batch_id::text,jsonb_build_object('medication_id',p_medication_id,'batch_number',p_batch_number,'quantity',p_quantity));
 return jsonb_build_object('batch_id',v_batch_id,'quantity_received',p_quantity);
end $$;
revoke all on function public.receive_pharmacy_stock(uuid,uuid,text,numeric,date,numeric,numeric,text) from public,anon;
grant execute on function public.receive_pharmacy_stock(uuid,uuid,text,numeric,date,numeric,numeric,text) to authenticated;

create or replace function public.record_clinic_lab_result(p_clinic_id uuid,p_lab_order_item_id uuid,p_result_text text,p_result_numeric numeric default null,p_abnormal_flag text default 'unknown')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_order_id uuid; v_test_name text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','lab_technician']) then raise exception 'Laboratory result permission required'; end if;
 if coalesce(trim(p_result_text),'')='' and p_result_numeric is null then raise exception 'A text or numeric result is required'; end if;
 if p_abnormal_flag not in ('low','normal','high','critical','unknown') then raise exception 'Invalid abnormal flag'; end if;
 select i.lab_order_id,i.test_name into v_order_id,v_test_name from public.lab_order_items i join public.lab_orders o on o.id=i.lab_order_id and o.clinic_id=i.clinic_id where i.id=p_lab_order_item_id and i.clinic_id=p_clinic_id and o.status not in ('cancelled','completed') for update of i;
 if v_order_id is null then raise exception 'Open lab order item not found in this clinic'; end if;
 update public.lab_order_items set result_text=nullif(trim(coalesce(p_result_text,'')),''),result_numeric=p_result_numeric,abnormal_flag=p_abnormal_flag,status='completed',reported_by=v_user,reported_at=now() where id=p_lab_order_item_id and clinic_id=p_clinic_id;
 if not exists(select 1 from public.lab_order_items i where i.lab_order_id=v_order_id and i.clinic_id=p_clinic_id and i.status not in ('completed','cancelled')) then update public.lab_orders set status='completed',completed_at=now() where id=v_order_id and clinic_id=p_clinic_id; else update public.lab_orders set status='processing' where id=v_order_id and clinic_id=p_clinic_id; end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'record_lab_result','lab_order_item',p_lab_order_item_id::text,jsonb_build_object('order_id',v_order_id,'test_name',v_test_name,'abnormal_flag',p_abnormal_flag));
 return jsonb_build_object('order_id',v_order_id,'item_id',p_lab_order_item_id,'status','completed');
end $$;
revoke all on function public.record_clinic_lab_result(uuid,uuid,text,numeric,text) from public,anon;
grant execute on function public.record_clinic_lab_result(uuid,uuid,text,numeric,text) to authenticated;
