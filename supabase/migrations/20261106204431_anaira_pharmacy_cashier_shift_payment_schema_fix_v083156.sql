-- Cashier shift reconciliation uses the actual payments table and paid_at timestamp.
create or replace function public.pharmacy_close_cashier_shift(p_clinic_id uuid,p_shift_id uuid,p_counted_cash numeric,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.pharmacy_cashier_shifts%rowtype; collected numeric:=0; refunds numeric:=0; expected numeric;
begin
 select * into r from public.pharmacy_cashier_shifts where id=p_shift_id and clinic_id=p_clinic_id and cashier_id=u and status='open' for update;
 if not found then raise exception 'Your open cashier shift was not found'; end if;
 if p_counted_cash<0 then raise exception 'Counted cash cannot be negative'; end if;
 select coalesce(sum(p.amount),0) into collected from public.payments p where p.clinic_id=p_clinic_id and p.received_by=u and p.paid_at>=r.opened_at and p.status in ('paid','completed','success');
 expected:=r.opening_cash+collected-refunds;
 update public.pharmacy_cashier_shifts set closed_at=now(),expected_cash=expected,counted_cash=p_counted_cash,cash_variance=p_counted_cash-expected,status='closed',notes=p_notes where id=p_shift_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_cashier_shift_closed','cashier_shift',p_shift_id::text,jsonb_build_object('collections',collected,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected));
 return jsonb_build_object('shift_no',r.shift_no,'opening_cash',r.opening_cash,'collections',collected,'refunds',refunds,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected);
end $$;
