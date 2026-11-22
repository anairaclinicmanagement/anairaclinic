-- Link a single OPD parchi to the encounter, prescription, laboratory order and lab invoice.
-- This migration is already applied to the dedicated Anaira Clinic Supabase project.
alter table public.opd_visits add column if not exists encounter_id uuid references public.encounters(id) on delete set null;
alter table public.opd_visits add column if not exists prescription_id uuid references public.prescriptions(id) on delete set null;
alter table public.opd_visits add column if not exists lab_order_id uuid references public.lab_orders(id) on delete set null;
alter table public.opd_visits add column if not exists lab_invoice_id uuid references public.invoices(id) on delete set null;

create or replace function public.process_opd_parchi_orders(p_clinic_id uuid,p_visit_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); v public.opd_visits%rowtype; e uuid; rx jsonb; lab uuid; inv uuid; invno text; labno text;
 it jsonb; nm text; mid uuid; tid uuid; price numeric; total numeric:=0; cnt int:=0;
 meds jsonb:='[]'::jsonb; tests jsonb:='[]'::jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 select * into v from public.opd_visits where id=p_visit_id and clinic_id=p_clinic_id for update;
 if v.id is null then raise exception 'OPD parchi not found'; end if;
 if not (private.has_clinic_role(p_clinic_id,array['owner','admin']) or (private.has_clinic_role(p_clinic_id,array['doctor']) and v.doctor_user_id=u)) then raise exception 'Only assigned doctor or clinic admin can send orders'; end if;
 if v.prescription_id is not null or v.lab_order_id is not null then raise exception 'Orders already linked to this parchi; duplicate creation blocked'; end if;
 if v.prescription_saved_at is null then raise exception 'Save diagnosis, medicines and tests first'; end if;
 if jsonb_array_length(coalesce(v.prescribed_medicines,'[]'::jsonb))=0 and jsonb_array_length(coalesce(v.prescribed_tests,'[]'::jsonb))=0 then raise exception 'Add at least one medicine or test first'; end if;
 insert into public.encounters(clinic_id,branch_id,patient_id,encounter_type,chief_complaint,assessment,plan,status,created_by)
 values(p_clinic_id,v.branch_id,v.patient_id,'opd',v.complaint,v.diagnosis,v.doctor_notes,'open',u) returning id into e;
 if jsonb_array_length(coalesce(v.prescribed_medicines,'[]'::jsonb))>0 then
  for it in select value from jsonb_array_elements(v.prescribed_medicines) loop
   nm:=trim(coalesce(it->>'medicine_name',it->>'name',''));
   if nm<>'' then
    select id into mid from public.medications where clinic_id=p_clinic_id and active and lower(trim(name))=lower(nm) limit 1;
    if mid is null then raise exception 'Medicine "%" is not in the active medicine catalogue. Add the medicine first.',nm; end if;
    meds:=meds||jsonb_build_array(jsonb_build_object('medication_id',mid,'medicine_name',nm,'dose',it->>'dose','frequency',it->>'frequency','duration_days',it->>'duration_days','quantity',coalesce(it->>'quantity','1'),'timing_instructions',it->>'timing_instructions','notes',it->>'notes'));
   end if;
  end loop;
  if jsonb_array_length(meds)>0 then rx:=public.create_clinic_prescription(p_clinic_id,v.patient_id,meds,v.doctor_notes,e); end if;
 end if;
 if jsonb_array_length(coalesce(v.prescribed_tests,'[]'::jsonb))>0 then
  lab:=gen_random_uuid(); labno:='LAB-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(lab::text,'-',''),1,8));
  insert into public.lab_orders(id,clinic_id,patient_id,encounter_id,ordered_by,order_no,status,ordered_at,notes)
  values(lab,p_clinic_id,v.patient_id,e,(select id from public.staff_profiles where clinic_id=p_clinic_id and user_id=u limit 1),labno,'ordered',now(),'From OPD parchi '||v.visit_no);
  inv:=gen_random_uuid(); invno:='LAB-BILL-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(inv::text,'-',''),1,8));
  insert into public.invoices(id,clinic_id,patient_id,encounter_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
  values(inv,p_clinic_id,v.patient_id,e,invno,'issued',0,0,0,now(),u);
  for it in select value from jsonb_array_elements(v.prescribed_tests) loop
   nm:=trim(coalesce(it->>'test_name',it->>'name',it->>'medicine_name',''));
   if nm<>'' then
    select id,name,price into tid,nm,price from public.lab_tests where clinic_id=p_clinic_id and active and lower(trim(name))=lower(nm) limit 1;
    if tid is null then raise exception 'Test "%" is not in the active test catalogue. Add the test first.',nm; end if;
    insert into public.lab_order_items(clinic_id,lab_order_id,lab_test_id,test_name,status) values(p_clinic_id,lab,tid,nm,'pending');
    insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,inv,'laboratory','Lab test: '||nm,1,price,price);
    total:=total+price; cnt:=cnt+1; tests:=tests||jsonb_build_array(jsonb_build_object('test_id',tid,'name',nm,'price',price));
   end if;
  end loop;
  update public.invoices set subtotal=total,total_amount=total,updated_at=now() where id=inv and clinic_id=p_clinic_id;
 end if;
 update public.opd_visits set encounter_id=e,prescription_id=nullif(rx->>'id','')::uuid,lab_order_id=lab,lab_invoice_id=inv,
  status=case when lab is not null then 'sent_to_lab' when rx is not null then 'sent_to_pharmacy' else status end,updated_at=now()
 where id=p_visit_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,u,'process_opd_parchi_orders','opd_visit',p_visit_id::text,jsonb_build_object('encounter_id',e,'prescription_id',rx->>'id','lab_order_id',lab,'lab_invoice_id',inv,'test_count',cnt));
 return jsonb_build_object('visit_id',p_visit_id,'encounter_id',e,'prescription_id',rx->>'id','prescription_no',rx->>'prescription_no','lab_order_id',lab,'lab_order_no',labno,'lab_invoice_id',inv,'lab_invoice_no',invno,'lab_invoice_amount',total,'medicines',meds,'tests',tests,'status','processed');
end $$;
revoke all on function public.process_opd_parchi_orders(uuid,uuid) from public,anon;
grant execute on function public.process_opd_parchi_orders(uuid,uuid) to authenticated;
