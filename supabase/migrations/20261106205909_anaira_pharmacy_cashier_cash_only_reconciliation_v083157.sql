-- Cash drawer expected balance includes cash tenders only; non-cash tenders are reported separately.
create or replace function public.pharmacy_close_cashier_shift(p_clinic_id uuid,p_shift_id uuid,p_counted_cash numeric,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.pharmacy_cashier_shifts%rowtype; cash_collected numeric:=0; non_cash numeric:=0; expected numeric; refunds numeric:=0;
begin
 select * into r from public.pharmacy_cashier_shifts where id=p_shift_id and clinic_id=p_clinic_id and cashier_id=u and status='open' for update;
 if not found then raise exception 'Your open cashier shift was not found'; end if;
 if p_counted_cash<0 then raise exception 'Counted cash cannot be negative'; end if;
 select coalesce(sum(amount) filter(where lower(method)='cash'),0),coalesce(sum(amount) filter(where lower(method)<>'cash'),0) into cash_collected,non_cash
 from public.payments where clinic_id=p_clinic_id and received_by=u and paid_at>=r.opened_at and status in ('paid','completed','success');
 expected:=r.opening_cash+cash_collected-refunds;
 update public.pharmacy_cashier_shifts set closed_at=now(),expected_cash=expected,counted_cash=p_counted_cash,cash_variance=p_counted_cash-expected,status='closed',notes=p_notes where id=p_shift_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,u,'pharmacy_cashier_shift_closed','cashier_shift',p_shift_id::text,jsonb_build_object('cash_collections',cash_collected,'non_cash_collections',non_cash,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected));
 return jsonb_build_object('shift_no',r.shift_no,'opening_cash',r.opening_cash,'cash_collections',cash_collected,'non_cash_collections',non_cash,'refunds',refunds,'expected_cash',expected,'counted_cash',p_counted_cash,'variance',p_counted_cash-expected);
end $$;
