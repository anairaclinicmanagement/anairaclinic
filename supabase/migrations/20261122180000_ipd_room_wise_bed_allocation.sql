-- IPD room-wise allocation: reserve every active bed in a room as one admission.
alter table public.admissions
  add column if not exists allocation_mode text not null default 'bed',
  add column if not exists room_rate_per_12_hours numeric(12,2);

alter table public.admissions drop constraint if exists admissions_allocation_mode_check;
alter table public.admissions add constraint admissions_allocation_mode_check
  check (allocation_mode in ('bed','room'));

create table if not exists public.ipd_room_allocation_beds (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  admission_id uuid not null references public.admissions(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete restrict,
  bed_id uuid not null references public.room_beds(id) on delete restrict,
  bed_number text not null,
  rate_per_12_hours numeric(12,2) not null default 0 check (rate_per_12_hours >= 0),
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique(admission_id,bed_id)
);

create index if not exists ipd_room_allocation_admission_idx
  on public.ipd_room_allocation_beds(clinic_id,admission_id);
create index if not exists ipd_room_allocation_room_idx
  on public.ipd_room_allocation_beds(clinic_id,room_id,released_at);
create unique index if not exists ipd_room_allocation_active_bed_uidx
  on public.ipd_room_allocation_beds(bed_id) where released_at is null;

alter table public.ipd_room_allocation_beds enable row level security;
drop policy if exists ipd_room_allocation_beds_select on public.ipd_room_allocation_beds;
create policy ipd_room_allocation_beds_select on public.ipd_room_allocation_beds
  for select to authenticated
  using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','staff','accountant']));

create or replace function public.release_ipd_room_allocation_beds_on_admission_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if (new.status not in ('admitted','transferred'))
     or new.bed_id is distinct from old.bed_id
     or new.room_id is distinct from old.room_id then
    update public.ipd_room_allocation_beds
       set released_at=coalesce(released_at,now())
     where admission_id=old.id and clinic_id=old.clinic_id and released_at is null;
  end if;
  return new;
end $$;

drop trigger if exists trg_release_ipd_room_allocation_beds on public.admissions;
create trigger trg_release_ipd_room_allocation_beds
after update of status,bed_id,room_id on public.admissions
for each row execute function public.release_ipd_room_allocation_beds_on_admission_change();

create or replace function public.create_clinic_room_admission_v1(
 p_clinic_id uuid,p_patient_id uuid,p_room_id uuid,p_notes text default null,
 p_admission_type text default 'routine',p_referred_by text default null,
 p_provisional_diagnosis text default null,p_department text default null,
 p_consultant_name text default null,p_attendant_name text default null,
 p_attendant_relation text default null,p_attendant_phone text default null,
 p_admitted_at timestamptz default now()
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid();
 v_admission uuid:=gen_random_uuid();
 v_no text;
 v_bed_id uuid;
 v_bed_number text;
 v_bed_count integer;
 v_room_rate numeric(12,2);
 v_room_number text;
 v_ward_name text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse','receptionist']) then
   raise exception 'IPD admission permission required';
 end if;
 if p_admission_type not in ('routine','emergency','daycare','maternity','transfer') then
   raise exception 'Invalid admission type';
 end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then
   raise exception 'Patient not found in this clinic';
 end if;

 -- Serialize room allocation attempts, then lock every active bed in the room.
 select r.room_number,r.ward_name into v_room_number,v_ward_name
 from public.rooms r
 where r.id=p_room_id and r.clinic_id=p_clinic_id and r.active=true
 for update;
 if v_room_number is null then raise exception 'Active room not found in this clinic'; end if;

 perform 1 from public.room_beds b
 where b.room_id=p_room_id and b.clinic_id=p_clinic_id and b.active=true
 order by b.id for update;
 select count(*),coalesce(sum(b.price_per_12_hours),0)
 into v_bed_count,v_room_rate
 from public.room_beds b
 where b.room_id=p_room_id and b.clinic_id=p_clinic_id and b.active=true;
 if v_bed_count=0 then raise exception 'This room has no active beds'; end if;

 if exists(
   select 1 from public.admissions a
   join public.room_beds b on b.id=a.bed_id
   where a.clinic_id=p_clinic_id and b.room_id=p_room_id
     and a.status in ('admitted','transferred')
 ) or exists(
   select 1 from public.ipd_room_allocation_beds rb
   where rb.clinic_id=p_clinic_id and rb.room_id=p_room_id and rb.released_at is null
 ) then
   raise exception 'This room is not fully available. One or more beds are already allocated';
 end if;

 select b.id,b.bed_number into v_bed_id,v_bed_number
 from public.room_beds b
 where b.room_id=p_room_id and b.clinic_id=p_clinic_id and b.active=true
 order by b.bed_number,b.id limit 1;
 v_no:='IPD-'||to_char(coalesce(p_admitted_at,now()) at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

 insert into public.admissions(
   id,clinic_id,patient_id,room_id,bed_id,admission_no,status,admitted_at,notes,
   admission_type,referred_by,provisional_diagnosis,department,consultant_name,
   attendant_name,attendant_relation,attendant_phone,allocation_mode,room_rate_per_12_hours
 ) values(
   v_admission,p_clinic_id,p_patient_id,p_room_id,v_bed_id,v_no,'admitted',
   coalesce(p_admitted_at,now()),nullif(trim(coalesce(p_notes,'')),''),p_admission_type,
   nullif(trim(coalesce(p_referred_by,'')),''),nullif(trim(coalesce(p_provisional_diagnosis,'')),''),
   nullif(trim(coalesce(p_department,'')),''),nullif(trim(coalesce(p_consultant_name,'')),''),
   nullif(trim(coalesce(p_attendant_name,'')),''),nullif(trim(coalesce(p_attendant_relation,'')), ''),
   nullif(trim(coalesce(p_attendant_phone,'')),''),
   'room',v_room_rate
 );

 insert into public.ipd_room_allocation_beds(
   clinic_id,admission_id,room_id,bed_id,bed_number,rate_per_12_hours
 )
 select p_clinic_id,v_admission,p_room_id,b.id,b.bed_number,b.price_per_12_hours
 from public.room_beds b
 where b.room_id=p_room_id and b.clinic_id=p_clinic_id and b.active=true;

 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_room_admission','admission',v_admission::text,
   jsonb_build_object('admission_no',v_no,'patient_id',p_patient_id,'room_id',p_room_id,
     'primary_bed_id',v_bed_id,'bed_number',v_bed_number,'allocation_mode','room',
     'allocated_bed_count',v_bed_count,'room_rate_per_12_hours',v_room_rate));

 return jsonb_build_object(
   'id',v_admission,'admission_no',v_no,'patient_id',p_patient_id,
   'room_id',p_room_id,'bed_id',v_bed_id,'bed_number',v_bed_number,
   'allocation_mode','room','allocated_bed_count',v_bed_count,
   'room_rate_per_12_hours',v_room_rate,'status','admitted'
 );
end $$;

revoke all on function public.create_clinic_room_admission_v1(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) from public,anon;
grant execute on function public.create_clinic_room_admission_v1(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) to authenticated;


-- A bed reserved by a whole-room admission must not be reallocated individually
-- or used as a transfer destination by the older single-bed workflows.
create or replace function public.prevent_ipd_bed_double_allocation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and (new.bed_id is distinct from old.bed_id or new.room_id is distinct from old.room_id) then
    new.allocation_mode:='bed';
    new.room_rate_per_12_hours:=null;
  end if;
  if new.bed_id is not null and exists(
    select 1 from public.ipd_room_allocation_beds rb
    where rb.bed_id=new.bed_id
      and rb.released_at is null
      and rb.admission_id is distinct from new.id
  ) then
    raise exception 'This bed is reserved as part of a whole-room IPD allocation';
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_ipd_bed_double_allocation on public.admissions;
create trigger trg_prevent_ipd_bed_double_allocation
before insert or update on public.admissions
for each row execute function public.prevent_ipd_bed_double_allocation();
