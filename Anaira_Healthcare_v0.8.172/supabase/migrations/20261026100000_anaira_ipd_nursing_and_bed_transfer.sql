-- Anaira Clinic IPD workflow: audited bed transfers and nursing chart records.
create table if not exists public.admission_bed_transfers (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  admission_id uuid not null references public.admissions(id) on delete restrict,
  patient_id uuid not null references public.patients(id) on delete restrict,
  from_room_id uuid references public.rooms(id) on delete set null,
  to_room_id uuid not null references public.rooms(id) on delete restrict,
  reason text not null,
  transferred_by uuid references auth.users(id),
  transferred_at timestamptz not null default now()
);
create index if not exists admission_bed_transfers_clinic_admission_idx
  on public.admission_bed_transfers(clinic_id, admission_id, transferred_at desc);
alter table public.admission_bed_transfers enable row level security;
drop policy if exists admission_bed_transfers_select_role on public.admission_bed_transfers;
create policy admission_bed_transfers_select_role on public.admission_bed_transfers
  for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','staff']));
drop policy if exists admission_bed_transfers_insert_role on public.admission_bed_transfers;
create policy admission_bed_transfers_insert_role on public.admission_bed_transfers
  for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse']));

create or replace function public.transfer_clinic_admission_bed(
  p_clinic_id uuid, p_admission_id uuid, p_to_room_id uuid, p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := auth.uid(); v_patient uuid; v_from_room uuid; v_status text;
  v_capacity integer; v_occupied integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Bed transfer permission required'; end if;
  if coalesce(length(trim(p_reason)),0)<3 then raise exception 'Transfer reason must be at least 3 characters'; end if;
  select a.patient_id,a.room_id,a.status into v_patient,v_from_room,v_status
    from public.admissions a where a.id=p_admission_id and a.clinic_id=p_clinic_id for update;
  if v_patient is null or v_status not in ('admitted','transferred') then raise exception 'Active admission not found in this clinic'; end if;
  select r.bed_count into v_capacity from public.rooms r
    where r.id=p_to_room_id and r.clinic_id=p_clinic_id and r.active=true for update;
  if v_capacity is null then raise exception 'Destination room is not active in this clinic'; end if;
  if v_from_room=p_to_room_id then raise exception 'Patient is already assigned to this room'; end if;
  select count(*) into v_occupied from public.admissions a
    where a.clinic_id=p_clinic_id and a.room_id=p_to_room_id and a.status in ('admitted','transferred');
  if v_occupied>=v_capacity then raise exception 'Destination room has no available bed'; end if;
  insert into public.admission_bed_transfers(clinic_id,admission_id,patient_id,from_room_id,to_room_id,reason,transferred_by)
    values(p_clinic_id,p_admission_id,v_patient,v_from_room,p_to_room_id,trim(p_reason),v_user);
  update public.admissions set room_id=p_to_room_id,status='transferred'
    where id=p_admission_id and clinic_id=p_clinic_id;
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
    values(p_clinic_id,v_user,'transfer_ipd_bed','admission',p_admission_id::text,
      jsonb_build_object('from_room_id',v_from_room,'to_room_id',p_to_room_id,'reason',trim(p_reason)));
  return jsonb_build_object('admission_id',p_admission_id,'patient_id',v_patient,
    'from_room_id',v_from_room,'to_room_id',p_to_room_id,'status','transferred');
end $$;
revoke all on function public.transfer_clinic_admission_bed(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.transfer_clinic_admission_bed(uuid,uuid,uuid,text) to authenticated;

create or replace function public.create_ipd_nursing_record(
  p_clinic_id uuid, p_admission_id uuid, p_record_type text,
  p_observations jsonb default '{}'::jsonb, p_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := auth.uid(); v_patient uuid; v_record_id uuid; v_status text; v_staff_profile uuid;
  v_allowed text[] := array['vitals','nursing_note','intake_output','medication_administration','injection_iv','monitoring','shift_handover'];
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Nursing chart permission required'; end if;
  if not (p_record_type=any(v_allowed)) then raise exception 'Unsupported nursing record type'; end if;
  select a.patient_id,a.status into v_patient,v_status from public.admissions a
    where a.id=p_admission_id and a.clinic_id=p_clinic_id;
  if v_patient is null or v_status not in ('admitted','transferred') then raise exception 'Active admission not found in this clinic'; end if;
  select sp.id into v_staff_profile from public.staff_profiles sp
    where sp.clinic_id=p_clinic_id and sp.user_id=v_user limit 1;
  v_record_id:=gen_random_uuid();
  insert into public.nursing_records(id,clinic_id,admission_id,patient_id,record_type,observations,notes,recorded_by)
    values(v_record_id,p_clinic_id,p_admission_id,v_patient,p_record_type,
      coalesce(p_observations,'{}'::jsonb),nullif(trim(coalesce(p_notes,'')),''),v_staff_profile);
  insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
    values(p_clinic_id,v_user,'create_ipd_nursing_record','nursing_record',v_record_id::text,
      jsonb_build_object('admission_id',p_admission_id,'record_type',p_record_type));
  return jsonb_build_object('id',v_record_id,'admission_id',p_admission_id,
    'patient_id',v_patient,'record_type',p_record_type,'recorded_at',now());
end $$;
revoke all on function public.create_ipd_nursing_record(uuid,uuid,text,jsonb,text) from public,anon;
grant execute on function public.create_ipd_nursing_record(uuid,uuid,text,jsonb,text) to authenticated;
