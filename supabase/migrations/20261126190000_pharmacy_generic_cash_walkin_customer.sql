-- v0.8.211: Reusable generic pharmacy cash-sale customer.
-- Anonymous counter sales still require a patient FK in the existing atomic dispensing RPC.
-- This creates/reuses one clearly-labelled non-clinical placeholder per clinic, without
-- collecting a customer's name, phone, DOB, gender or address.
create or replace function public.get_or_create_pharmacy_cash_customer(p_clinic_id uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid;
  v_uhid text;
  v_marker constant text := 'ANAIRA_PHARMACY_GENERIC_CASH_CUSTOMER_V1';
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then
    raise exception 'Cash-sale customer creation is restricted to pharmacy staff and clinic administrators';
  end if;

  if not public.clinic_module_access(p_clinic_id,'pharmacy') then
    raise exception 'Pharmacy module is not enabled for this clinic';
  end if;

  -- Serialize concurrent first-time cash sales for the same clinic.
  perform pg_advisory_xact_lock(hashtextextended(p_clinic_id::text || ':pharmacy-cash-customer',0));

  select p.id into v_id
  from public.patients p
  where p.clinic_id=p_clinic_id
    and p.first_name='Cash / Walk-in'
    and p.last_name='Customer'
    and p.notes=v_marker
  order by p.created_at
  limit 1;

  if v_id is null then
    v_id := gen_random_uuid();
    v_uhid := 'UHID-' ||
      to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD') || '-' ||
      upper(substr(replace(v_id::text,'-',''),1,8));

    insert into public.patients(
      id,clinic_id,uhid,first_name,last_name,gender,notes,created_by
    )
    values(
      v_id,p_clinic_id,v_uhid,'Cash / Walk-in','Customer','unknown',v_marker,auth.uid()
    );
  end if;

  return v_id;
end;
$$;

revoke all on function public.get_or_create_pharmacy_cash_customer(uuid) from public,anon;
grant execute on function public.get_or_create_pharmacy_cash_customer(uuid) to authenticated;
