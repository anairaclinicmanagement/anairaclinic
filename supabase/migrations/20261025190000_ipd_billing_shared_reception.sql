-- Shared IPD billing: invoices created from IPD are the same invoices visible at Reception > Billing.
alter table public.invoices add column if not exists admission_id uuid references public.admissions(id) on delete set null;
create index if not exists invoices_clinic_admission_idx on public.invoices(clinic_id, admission_id, created_at desc) where admission_id is not null;

create or replace function public.create_ipd_invoice(
 p_clinic_id uuid, p_admission_id uuid, p_description text, p_amount numeric,
 p_collect_now boolean default false, p_payment_method text default 'cash'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_status text; v_invoice uuid:=gen_random_uuid(); v_no text; v_paid numeric:=0;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','receptionist','accountant']) then raise exception 'IPD billing permission required'; end if;
 if coalesce(trim(p_description),'')='' then raise exception 'Bill description is required'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'Enter a valid bill amount'; end if;
 if p_payment_method not in ('cash','card','upi','bank_transfer','insurance','other') then raise exception 'Unsupported payment method'; end if;
 select a.patient_id into v_patient from public.admissions a where a.id=p_admission_id and a.clinic_id=p_clinic_id and a.status in ('admitted','transferred','discharged');
 if v_patient is null then raise exception 'Admission not found in this clinic'; end if;
 if coalesce(p_collect_now,false) then v_paid:=p_amount; end if;
 v_no:='IPD-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice::text,'-',''),1,8));
 v_status:=case when v_paid>=p_amount then 'paid' else 'issued' end;
 insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by)
 values(v_invoice,p_clinic_id,v_patient,p_admission_id,v_no,v_status,p_amount,p_amount,v_paid,now(),v_user);
 insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total)
 values(p_clinic_id,v_invoice,'ipd',trim(p_description),1,p_amount,p_amount);
 if v_paid>0 then
  insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,status,received_by,paid_at,notes)
  values(p_clinic_id,v_invoice,v_patient,v_paid,p_payment_method,'completed',v_user,now(),'IPD bill payment');
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_ipd_invoice','invoice',v_invoice::text,jsonb_build_object('invoice_no',v_no,'admission_id',p_admission_id,'amount',p_amount,'paid_amount',v_paid));
 return jsonb_build_object('id',v_invoice,'invoice_no',v_no,'patient_id',v_patient,'admission_id',p_admission_id,'total_amount',p_amount,'paid_amount',v_paid,'status',v_status);
end $$;
revoke all on function public.create_ipd_invoice(uuid,uuid,text,numeric,boolean,text) from public,anon;
grant execute on function public.create_ipd_invoice(uuid,uuid,text,numeric,boolean,text) to authenticated;

-- Permit clinical IPD staff to see only invoices attached to an admission in their own clinic.
drop policy if exists ipd_invoices_select_clinical on public.invoices;
create policy ipd_invoices_select_clinical on public.invoices for select to authenticated
using (admission_id is not null and private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','accountant']));
