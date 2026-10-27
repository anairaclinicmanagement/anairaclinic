-- Pharmacy advanced suppliers and audited stock corrections; clinic-scoped.
create table if not exists public.pharmacy_suppliers (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id) on delete cascade,
 supplier_name text not null,
 phone text,
 email text,
 gstin text,
 address text,
 notes text,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint pharmacy_suppliers_name_nonblank check (length(trim(supplier_name)) > 0)
);
create unique index if not exists pharmacy_suppliers_clinic_name_unique on public.pharmacy_suppliers(clinic_id, lower(supplier_name));
create index if not exists pharmacy_suppliers_clinic_active_idx on public.pharmacy_suppliers(clinic_id, active);
alter table public.pharmacy_suppliers enable row level security;
drop policy if exists pharmacy_suppliers_select on public.pharmacy_suppliers;
create policy pharmacy_suppliers_select on public.pharmacy_suppliers for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','pharmacist','accountant']));
drop policy if exists pharmacy_suppliers_insert on public.pharmacy_suppliers;
create policy pharmacy_suppliers_insert on public.pharmacy_suppliers for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','pharmacist']));
drop policy if exists pharmacy_suppliers_update on public.pharmacy_suppliers;
create policy pharmacy_suppliers_update on public.pharmacy_suppliers for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','pharmacist'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','pharmacist']));

create or replace function public.adjust_pharmacy_batch(
 p_clinic_id uuid, p_batch_id uuid, p_new_quantity numeric, p_reason text, p_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_old numeric; v_med uuid; v_batch text; v_delta numeric;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Pharmacy stock adjustment permission required'; end if;
 if not public.clinic_module_access(p_clinic_id,'pharmacy') then raise exception 'Pharmacy module is not enabled for this clinic'; end if;
 if p_new_quantity is null or p_new_quantity<0 or p_new_quantity>10000000 then raise exception 'New quantity must be between 0 and 10,000,000'; end if;
 if coalesce(trim(p_reason),'') not in ('Physical count correction','Damaged stock','Expired stock','Breakage','Opening balance correction','Other') then raise exception 'Select a valid stock adjustment reason'; end if;
 select quantity_on_hand,medication_id,batch_number into v_old,v_med,v_batch from public.inventory_batches where id=p_batch_id and clinic_id=p_clinic_id for update;
 if not found then raise exception 'Stock batch not found in selected clinic'; end if;
 v_delta:=p_new_quantity-v_old;
 if v_delta=0 then return jsonb_build_object('batch_id',p_batch_id,'quantity_before',v_old,'quantity_after',v_old,'quantity_delta',0,'message','No quantity change'); end if;
 update public.inventory_batches set quantity_on_hand=p_new_quantity where id=p_batch_id and clinic_id=p_clinic_id;
 insert into public.stock_movements(clinic_id,batch_id,movement_type,quantity,reference_type,reference_id,notes,created_by)
 values(p_clinic_id,p_batch_id,'adjustment',abs(v_delta),'stock_adjustment',p_batch_id,trim(p_reason)||case when coalesce(trim(p_notes),'')<>'' then ': '||trim(p_notes) else '' end||' | delta='||v_delta::text,v_user);
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'adjust_pharmacy_batch','inventory_batch',p_batch_id::text,jsonb_build_object('medication_id',v_med,'batch_number',v_batch,'quantity_before',v_old,'quantity_after',p_new_quantity,'quantity_delta',v_delta,'reason',p_reason,'notes',p_notes));
 return jsonb_build_object('batch_id',p_batch_id,'quantity_before',v_old,'quantity_after',p_new_quantity,'quantity_delta',v_delta);
end $$;
revoke all on function public.adjust_pharmacy_batch(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.adjust_pharmacy_batch(uuid,uuid,numeric,text,text) to authenticated;
