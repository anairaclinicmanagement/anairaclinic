-- Configurable OPD registration fees: weekday, Sunday, selected holidays and emergency.
create or replace function public.set_clinic_opd_fee_policy(p_clinic_id uuid,p_fee_policy jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_dates jsonb; v_key text; v_amount numeric;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin']) then raise exception 'Only clinic owner/admin can change OPD fee rules'; end if;
 if jsonb_typeof(p_fee_policy)<>'object' then raise exception 'Fee policy must be an object'; end if;
 foreach v_key in array array['daily_fee','sunday_fee','holiday_fee','emergency_fee'] loop
  v_amount:=coalesce(nullif(p_fee_policy->>v_key,'')::numeric,0);
  if v_amount<0 or v_amount>1000000 then raise exception 'OPD fee must be between 0 and 1000000'; end if;
 end loop;
 v_dates:=coalesce(p_fee_policy->'holiday_dates','[]'::jsonb);
 if jsonb_typeof(v_dates)<>'array' or jsonb_array_length(v_dates)>100 then raise exception 'Holiday dates must be a list of at most 100 dates'; end if;
 if exists(select 1 from jsonb_array_elements_text(v_dates) x where x !~ '^\d{4}-\d{2}-\d{2}$') then raise exception 'Holiday dates must use YYYY-MM-DD'; end if;
 insert into public.clinic_settings(clinic_id,settings,updated_by,updated_at) values(p_clinic_id,jsonb_build_object('opd_registration_fee_policy',p_fee_policy),v_user,now())
 on conflict(clinic_id) do update set settings=public.clinic_settings.settings||jsonb_build_object('opd_registration_fee_policy',p_fee_policy),updated_by=v_user,updated_at=now();
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,details) values(p_clinic_id,v_user,'update_opd_registration_fee_policy','clinic_settings',p_fee_policy);
 return p_fee_policy;
end $$;
revoke all on function public.set_clinic_opd_fee_policy(uuid,jsonb) from public,anon;
grant execute on function public.set_clinic_opd_fee_policy(uuid,jsonb) to authenticated;

create or replace function public.create_clinic_opd_visit_intake_v2(
 p_clinic_id uuid, p_patient_id uuid default null, p_first_name text default null,
 p_last_name text default null, p_phone text default null, p_gender text default null,
 p_date_of_birth date default null, p_complaint text default null,
 p_department text default 'General OPD', p_doctor_name text default 'Duty Doctor',
 p_doctor_user_id uuid default null, p_notify_doctor boolean default false,
 p_branch_id uuid default null, p_collect_registration_fee boolean default true,
 p_payment_method text default 'cash', p_visit_type text default 'New'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid(); v_patient uuid:=p_patient_id; v_uhid text;
 v_days integer:=7; v_fee numeric:=0; v_id uuid:=gen_random_uuid(); v_no text;
 v_until date; v_policy jsonb:='{}'::jsonb; v_today date:=(now() at time zone 'Asia/Kolkata')::date; v_invoice uuid; v_invoice_no text; v_status text; v_room text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist']) then raise exception 'Reception/clinic admin permission required'; end if;
 if length(trim(coalesce(p_complaint,'')))<2 then raise exception 'Please record the patient complaint'; end if;
 if length(trim(coalesce(p_department,'')))<2 or length(trim(coalesce(p_doctor_name,'')))<2 then raise exception 'Select department and doctor'; end if;
 if coalesce(p_visit_type,'New') not in ('New','Follow-up','Emergency') then raise exception 'Unsupported OPD visit type'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 if v_patient is null then
  if length(trim(coalesce(p_first_name,'')))<1 or length(trim(p_first_name))>100 then raise exception 'Patient first name is required'; end if;
  if nullif(trim(coalesce(p_phone,'')),'') is not null then
   select p.id into v_patient from public.patients p where p.clinic_id=p_clinic_id and p.archived_at is null and regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=regexp_replace(trim(p_phone),'[^0-9]','','g') order by p.created_at asc limit 1;
  end if;
  if v_patient is null then
   v_patient:=gen_random_uuid(); v_uhid:='UHID-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_patient::text,'-',''),1,8));
   insert into public.patients(id,clinic_id,branch_id,uhid,first_name,last_name,phone,gender,date_of_birth,created_by)
   values(v_patient,p_clinic_id,p_branch_id,v_uhid,trim(p_first_name),nullif(trim(coalesce(p_last_name,'')),''),nullif(trim(coalesce(p_phone,'')),''),nullif(p_gender,''),p_date_of_birth,v_user);
  end if;
 end if;
 if not exists(select 1 from public.patients p where p.id=v_patient and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 if p_branch_id is not null and not exists(select 1 from public.clinic_branches b where b.id=p_branch_id and b.clinic_id=p_clinic_id and b.active=true) then raise exception 'Branch does not belong to this clinic'; end if;
 if p_doctor_user_id is not null and not exists(select 1 from public.staff_profiles s join public.clinic_members m on m.clinic_id=s.clinic_id and m.user_id=s.user_id and m.active=true where s.clinic_id=p_clinic_id and s.user_id=p_doctor_user_id and s.role='doctor' and s.active=true) then raise exception 'Selected doctor login is not active in this clinic'; end if;
 select greatest(1,least(365,coalesce(nullif(settings->>'opd_parchi_validity_days','')::integer,7))),greatest(0,coalesce(nullif(settings->>'opd_registration_fee','')::numeric,0)),coalesce(settings->'opd_registration_fee_policy','{}'::jsonb) into v_days,v_fee,v_policy from public.clinic_settings where clinic_id=p_clinic_id;
 v_days:=coalesce(v_days,7); v_fee:=coalesce(v_fee,0); v_policy:=coalesce(v_policy,'{}'::jsonb);
 if lower(coalesce(p_visit_type,''))='emergency' then v_fee:=greatest(0,coalesce(nullif(v_policy->>'emergency_fee','')::numeric,v_fee));
 elsif coalesce(v_policy->'holiday_dates','[]'::jsonb) @> to_jsonb(to_char(v_today,'YYYY-MM-DD')) then v_fee:=greatest(0,coalesce(nullif(v_policy->>'holiday_fee','')::numeric,v_fee));
 elsif extract(dow from v_today)=0 then v_fee:=greatest(0,coalesce(nullif(v_policy->>'sunday_fee','')::numeric,v_fee));
 else v_fee:=greatest(0,coalesce(nullif(v_policy->>'daily_fee','')::numeric,v_fee)); end if;
 v_until:=v_today+v_days-1;
 v_no:='OPD-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_id::text,'-',''),1,8));
 if p_doctor_user_id is not null then select room_number into v_room from public.staff_profiles where clinic_id=p_clinic_id and user_id=p_doctor_user_id and active=true limit 1; end if;
 if v_fee>0 then
  v_invoice:=gen_random_uuid(); v_invoice_no:='REG-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8)); v_status:=case when p_collect_registration_fee then 'paid' else 'issued' end;
  insert into public.invoices(id,clinic_id,branch_id,patient_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice,p_clinic_id,p_branch_id,v_patient,v_invoice_no,v_status,v_fee,v_fee,case when p_collect_registration_fee then v_fee else 0 end,now(),v_user);
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice,'service','OPD registration / parchi fee',1,v_fee,v_fee);
  if p_collect_registration_fee then insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at) values(p_clinic_id,v_invoice,v_patient,v_fee,p_payment_method,'completed',v_user,now()); end if;
 end if;
 insert into public.opd_visits(id,clinic_id,branch_id,patient_id,visit_no,complaint,department,doctor_name,doctor_user_id,doctor_room,notify_doctor,notified_at,validity_days,valid_until,registration_fee,invoice_id,status,created_by,patient_snapshot)
 select v_id,p_clinic_id,p_branch_id,v_patient,v_no,trim(p_complaint),trim(p_department),trim(p_doctor_name),p_doctor_user_id,v_room,coalesce(p_notify_doctor,false) and p_doctor_user_id is not null,case when coalesce(p_notify_doctor,false) and p_doctor_user_id is not null then now() else null end,v_days,v_until,v_fee,v_invoice,'waiting',v_user,jsonb_build_object('full_name',concat_ws(' ',p.first_name,p.middle_name,p.last_name),'uhid',p.uhid,'phone',p.phone,'gender',p.gender,'date_of_birth',p.date_of_birth) from public.patients p where p.id=v_patient and p.clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_opd_parchi_auto_patient','opd_visit',v_id::text,jsonb_build_object('visit_no',v_no,'patient_id',v_patient,'doctor_user_id',p_doctor_user_id,'doctor_room',v_room,'valid_until',v_until));
 return jsonb_build_object('id',v_id,'visit_no',v_no,'patient_id',v_patient,'doctor_name',trim(p_doctor_name),'doctor_user_id',p_doctor_user_id,'doctor_room',v_room,'validity_days',v_days,'valid_until',v_until,'registration_fee',v_fee,'invoice_id',v_invoice,'invoice_no',v_invoice_no,'invoice_status',v_status,'status','waiting');
end $$;
revoke all on function public.create_clinic_opd_visit_intake_v2(uuid,uuid,text,text,text,text,date,text,text,text,uuid,boolean,uuid,boolean,text,text) from public,anon;
grant execute on function public.create_clinic_opd_visit_intake_v2(uuid,uuid,text,text,text,text,date,text,text,text,uuid,boolean,uuid,boolean,text,text) to authenticated;
