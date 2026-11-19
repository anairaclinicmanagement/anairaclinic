-- Store-aware supplier return. The base procurement return RPC posts supplier credit and
-- decreases the batch balance. This wrapper additionally debits the selected store
-- balance and writes a matching immutable inventory ledger transaction atomically.
create or replace function public.create_pharmacy_purchase_return_from_store(p_clinic_id uuid,p_supplier_id uuid,p_items jsonb,p_reason text,p_grn_id uuid default null,p_store_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); res jsonb; rid uuid; st uuid; x jsonb; bid uuid; med uuid; qty numeric; available numeric;
begin
 if u is null or not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Purchase return permission required'; end if;
 st:=coalesce(p_store_id,(select id from public.pharmacy_stores where clinic_id=p_clinic_id and store_code='MAIN' and active limit 1));
 if st is null or not exists(select 1 from public.pharmacy_stores where id=st and clinic_id=p_clinic_id and active) then raise exception 'Select an active return store'; end if;
 res:=public.create_pharmacy_purchase_return(p_clinic_id,p_supplier_id,p_items,p_reason,p_grn_id);
 select id into rid from public.pharmacy_purchase_returns where clinic_id=p_clinic_id and return_no=res->>'return_no';
 if rid is null then raise exception 'Purchase return reference could not be resolved'; end if;
 for x in select value from jsonb_array_elements(p_items) loop
  bid:=(x->>'batch_id')::uuid; qty:=(x->>'quantity')::numeric;
  select medication_id,quantity into med,available from public.pharmacy_store_stock where clinic_id=p_clinic_id and store_id=st and batch_id=bid for update;
  if not found or available<qty then raise exception 'Selected store does not have enough stock for batch %',bid; end if;
  update public.pharmacy_store_stock set quantity=quantity-qty where clinic_id=p_clinic_id and store_id=st and batch_id=bid;
  insert into public.pharmacy_inventory_ledger(clinic_id,store_id,batch_id,medication_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by)
  values(p_clinic_id,st,bid,med,'purchase_return',-qty,'purchase_return',rid,p_reason,u);
 end loop;
 return res||jsonb_build_object('store_id',st);
end $$;
grant execute on function public.create_pharmacy_purchase_return_from_store(uuid,uuid,jsonb,text,uuid,uuid) to authenticated;
