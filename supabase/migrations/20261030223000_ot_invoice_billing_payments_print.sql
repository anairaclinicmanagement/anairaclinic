-- OT final charge is issued as a normal IPD-linked invoice so Billing & Payments
-- can print it and collect full/partial payments using existing invoice workflows.
alter table public.operation_theatre_cases
  add column if not exists billing_invoice_id uuid references public.invoices(id) on delete set null;

create or replace function public.post_operation_theatre_charge_to_ipd(
  p_clinic_id uuid,
  p_case_id uuid,
  p_final_charge numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case public.operation_theatre_cases%rowtype;
  v_invoice_id uuid;
  v_invoice_no text;
  v_amount numeric;
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_clinic_role(p_clinic_id, array['owner','admin','doctor','nurse','accountant','receptionist']) then
    raise exception 'OT billing permission required';
  end if;
  if p_final_charge is not null and (p_final_charge < 0 or p_final_charge > 100000000) then
    raise exception 'Invalid final OT charge';
  end if;

  select * into v_case
  from public.operation_theatre_cases
  where id = p_case_id and clinic_id = p_clinic_id
  for update;
  if v_case.id is null then raise exception 'OT case not found'; end if;
  if v_case.status not in ('recovery','completed') then
    raise exception 'Complete surgery and move the patient to recovery before posting OT charge';
  end if;
  if v_case.admission_id is null then raise exception 'This case has no IPD admission. Link/admit patient before billing.'; end if;

  if v_case.billing_invoice_id is not null then
    return jsonb_build_object(
      'invoice_id', v_case.billing_invoice_id,
      'invoice_no', (select invoice_no from public.invoices where id = v_case.billing_invoice_id),
      'status', 'already_posted',
      'amount', v_case.final_operation_charge
    );
  end if;

  v_amount := coalesce(p_final_charge, v_case.estimated_cost, 0);
  if v_amount <= 0 then raise exception 'Enter a final OT charge greater than zero'; end if;
  if not exists (
    select 1 from public.admissions
    where id = v_case.admission_id and clinic_id = p_clinic_id
      and patient_id = v_case.patient_id and status in ('admitted','transferred')
  ) then raise exception 'Active matching IPD admission not found'; end if;

  v_invoice_id := gen_random_uuid();
  v_invoice_no := 'OT-' || to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD') || '-' || upper(substr(replace(v_invoice_id::text,'-',''),1,8));

  insert into public.invoices(
    id, clinic_id, patient_id, admission_id, invoice_no, status,
    subtotal, total_amount, paid_amount, issued_at, created_by
  ) values (
    v_invoice_id, p_clinic_id, v_case.patient_id, v_case.admission_id,
    v_invoice_no, 'issued', v_amount, v_amount, 0, now(), v_user
  );

  insert into public.invoice_items(
    clinic_id, invoice_id, item_type, description, quantity,
    unit_price, discount_amount, tax_percent, line_total
  ) values (
    p_clinic_id, v_invoice_id, 'ipd_operation',
    'Operation Theatre: ' || v_case.procedure_name,
    1, v_amount, 0, 0, v_amount
  );

  update public.operation_theatre_cases
  set final_operation_charge = v_amount,
      billing_invoice_id = v_invoice_id,
      billed_to_ipd_at = now(),
      updated_at = now()
  where id = v_case.id and clinic_id = p_clinic_id;

  insert into public.audit_logs(clinic_id, actor_user_id, action, entity_type, entity_id, details)
  values (
    p_clinic_id, v_user, 'post_ot_invoice_to_billing',
    'operation_theatre_case', v_case.id::text,
    jsonb_build_object('invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'amount',v_amount,'admission_id',v_case.admission_id)
  );

  return jsonb_build_object(
    'invoice_id',v_invoice_id,'invoice_no',v_invoice_no,
    'admission_id',v_case.admission_id,'amount',v_amount,'status','invoice_created'
  );
end;
$$;

revoke all on function public.post_operation_theatre_charge_to_ipd(uuid,uuid,numeric) from public, anon;
grant execute on function public.post_operation_theatre_charge_to_ipd(uuid,uuid,numeric) to authenticated;
notify pgrst, 'reload schema';
