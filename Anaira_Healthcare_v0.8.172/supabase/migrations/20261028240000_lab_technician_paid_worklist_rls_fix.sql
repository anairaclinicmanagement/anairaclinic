-- Allow lab technicians to see only their own clinic's fully paid laboratory orders.
-- SECURITY DEFINER avoids invoice RLS hiding the payment row from lab-technician sessions.
create or replace function private.can_lab_technician_read_paid_order(p_clinic_id uuid, p_order_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_members cm
    join public.clinics c on c.id=cm.clinic_id
    join public.lab_orders o on o.clinic_id=cm.clinic_id and o.id=p_order_id
    join public.invoices inv on inv.id=o.invoice_id and inv.clinic_id=o.clinic_id
    where cm.clinic_id=p_clinic_id and cm.user_id=(select auth.uid())
      and cm.active=true and cm.role='lab_technician' and c.platform_status='active'
      and o.department_key='laboratory' and inv.status='paid'
      and inv.paid_amount >= inv.total_amount
      and exists (select 1 from public.clinic_subscriptions s
        join public.clinic_plans p on p.id=s.plan_id
        where s.clinic_id=p_clinic_id and s.status in ('trial','active')
          and (s.ends_at is null or s.ends_at>now())
          and 'laboratory'=any(coalesce(p.enabled_modules,array[]::text[])))
  );
$$;
revoke all on function private.can_lab_technician_read_paid_order(uuid,uuid) from public;
grant execute on function private.can_lab_technician_read_paid_order(uuid,uuid) to authenticated;

-- Permissive SELECT policies are required in addition to the restrictive entitlement policies.
drop policy if exists lab_orders_select_labtech_paid on public.lab_orders;
create policy lab_orders_select_labtech_paid on public.lab_orders for select to authenticated
using (private.can_lab_technician_read_paid_order(clinic_id,id));
drop policy if exists lab_order_items_select_labtech_paid on public.lab_order_items;
create policy lab_order_items_select_labtech_paid on public.lab_order_items for select to authenticated
using (private.can_lab_technician_read_paid_order(clinic_id,lab_order_id));
