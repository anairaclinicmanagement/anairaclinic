-- Align central billing and pharmacist payment collection. Keep pharmacist restricted
-- to pharmacy-only invoices; authorised billing staff can collect any invoice including pharmacy.
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
 select exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=p_invoice_id and ii.item_type='pharmacy'),
        exists(select 1 from public.invoice_items ii where ii.clinic_id=p_clinic_id and ii.invoice_id=p_invoice_id and ii.item_type<>'pharmacy')
 into v_has_pharmacy,v_has_non_pharmacy;
 v_is_pharmacy_only:=v_has_pharmacy and not v_has_non_pharmacy;
 if private.has_clinic_role(p_clinic_id,array['pharmacist']) and not v_is_pharmacy_only then raise exception 'Pharmacist can collect payment only for pharmacy-only invoices.'; end if;
 if v_invoice.status in ('void','refunded','cancelled') then raise exception 'Cannot pay a void/refunded/cancelled invoice'; end if;
 if p_amount>v_invoice.total_amount-v_invoice.paid_amount then raise exception 'Payment exceeds outstanding balance'; end if;
 v_new_paid:=round(v_invoice.paid_amount+p_amount,2);
 v_status:=case when v_new_paid>=v_invoice.total_amount then 'paid' else 'part_paid' end;
 insert into public.payments(clinic_id,invoice_id,patient_id,amount,method,transaction_reference,status,received_by,paid_at)
 values(p_clinic_id,p_invoice_id,v_invoice.patient_id,p_amount,p_method,nullif(trim(coalesce(p_reference,'')),''),'completed',v_user,now());
 update public.invoices set paid_amount=v_new_paid,status=v_status,updated_at=now() where id=p_invoice_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'record_invoice_payment','invoice',p_invoice_id::text,jsonb_build_object('amount',p_amount,'method',p_method,'paid_total',v_new_paid,'status',v_status));
 return jsonb_build_object('invoice_id',p_invoice_id,'paid_amount',v_new_paid,'balance_due',greatest(0,v_invoice.total_amount-v_new_paid),'status',v_status);
end $$;
revoke all on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.record_clinic_invoice_payment(uuid,uuid,numeric,text,text) to authenticated;

drop policy if exists invoices_select_billing_roles on public.invoices;
create policy invoices_select_billing_roles on public.invoices for select to authenticated using (
 private.has_clinic_role(clinic_id,array['owner','admin','receptionist','accountant','billing'])
 or (private.has_clinic_role(clinic_id,array['pharmacist']) and exists(select 1 from public.invoice_items ii where ii.clinic_id=invoices.clinic_id and ii.invoice_id=invoices.id and ii.item_type='pharmacy') and not exists(select 1 from public.invoice_items ii where ii.clinic_id=invoices.clinic_id and ii.invoice_id=invoices.id and ii.item_type<>'pharmacy'))
);
drop policy if exists invoices_update_billing_roles on public.invoices;
create policy invoices_update_billing_roles on public.invoices for update to authenticated using (
 private.has_clinic_role(clinic_id,array['owner','admin','receptionist','accountant','billing'])
) with check (
 private.has_clinic_role(clinic_id,array['owner','admin','receptionist','accountant','billing'])
);
