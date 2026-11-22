-- Pharmacy counter can register an outside customer without creating an OPD visit.
create or replace function public.create_pharmacy_walkin_customer(
 p_clinic_id uuid,
 p_first_name text,
 p_last_name text default null,
 p_phone text default null,
 p_gender text default null,
 p_date_of_birth date default null,
 p_address text default null
) returns table(id uuid,clinic_id uuid,uhid text,first_name text,middle_name text,last_name text,phone text,gender text,date_of_birth date,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','pharmacist']) then raise exception 'Walk-in pharmacy customer creation is restricted to pharmacy staff and clinic administrators'; end if;
 if not public.clinic_module_access(p_clinic_id,'pharmacy') then raise exception 'Pharmacy module is not enabled for this clinic'; end if;
 if coalesce(length(trim(p_first_name)),0)=0 then raise exception 'Customer first name is required'; end if;
 if length(trim(p_first_name))>100 or length(coalesce(trim(p_last_name),''))>100 then raise exception 'Name is too long'; end if;
 if nullif(trim(coalesce(p_phone,'')),'') is not null and length(trim(p_phone))>30 then raise exception 'Phone number is too long'; end if;
 if p_gender is not null and p_gender not in ('female','male','other','unknown') then raise exception 'Invalid gender'; end if;
 insert into public.patients(clinic_id,first_name,last_name,phone,gender,date_of_birth,address,notes,created_by)
 values(p_clinic_id,trim(p_first_name),nullif(trim(coalesce(p_last_name,'')),''),nullif(trim(coalesce(p_phone,'')),''),p_gender,p_date_of_birth,
 case when nullif(trim(coalesce(p_address,'')),'') is null then '{}'::jsonb else jsonb_build_object('line1',trim(p_address)) end,
 'Pharmacy walk-in customer; created at pharmacy counter; no clinic visit implied.',auth.uid())
 returning patients.id into v_id;
 return query select p.id,p.clinic_id,p.uhid,p.first_name,p.middle_name,p.last_name,p.phone,p.gender,p.date_of_birth,p.created_at from public.patients p where p.id=v_id and p.clinic_id=p_clinic_id;
end $$;
revoke all on function public.create_pharmacy_walkin_customer(uuid,text,text,text,text,date,text) from public,anon;
grant execute on function public.create_pharmacy_walkin_customer(uuid,text,text,text,text,date,text) to authenticated;
