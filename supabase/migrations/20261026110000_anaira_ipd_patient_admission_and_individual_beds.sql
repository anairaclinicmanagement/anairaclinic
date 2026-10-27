-- Anaira Clinic IPD: full admission detail capture and individual physical bed allocation.
alter table public.admissions
  add column if not exists admission_type text not null default 'routine',
  add column if not exists referred_by text,
  add column if not exists provisional_diagnosis text,
  add column if not exists department text,
  add column if not exists consultant_name text,
  add column if not exists attendant_name text,
  add column if not exists attendant_relation text,
  add column if not exists attendant_phone text,
  add column if not exists bed_id uuid;

alter table public.admissions drop constraint if exists admissions_admission_type_check;
alter table public.admissions add constraint admissions_admission_type_check
  check (admission_type in ('routine','emergency','daycare','maternity','transfer'));

create table if not exists public.room_beds (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  bed_number text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(room_id,bed_number),
  unique(id,clinic_id)
);
alter table public.admissions drop constraint if exists admissions_bed_id_fkey;
alter table public.admissions add constraint admissions_bed_id_fkey
  foreign key (bed_id) references public.room_beds(id) on delete set null;
create index if not exists room_beds_clinic_room_idx on public.room_beds(clinic_id,room_id,active,bed_number);
create index if not exists admissions_clinic_bed_status_idx on public.admissions(clinic_id,bed_id,status);

insert into public.room_beds(clinic_id,room_id,bed_number)
select r.clinic_id,r.id,r.room_number||'-'||g.n::text
from public.rooms r
cross join lateral generate_series(1,least(greatest(r.bed_count,1),500)) as g(n)
on conflict (room_id,bed_number) do nothing;

alter table public.room_beds enable row level security;
drop policy if exists room_beds_select_role on public.room_beds;
create policy room_beds_select_role on public.room_beds for select to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','receptionist','staff','accountant']));
drop policy if exists room_beds_insert_role on public.room_beds;
create policy room_beds_insert_role on public.room_beds for insert to authenticated
with check (private.has_clinic_role(clinic_id,array['owner','admin']));
drop policy if exists room_beds_update_role on public.room_beds;
create policy room_beds_update_role on public.room_beds for update to authenticated
using (private.has_clinic_role(clinic_id,array['owner','admin']))
with check (private.has_clinic_role(clinic_id,array['owner','admin']));

create or replace function public.create_clinic_admission_v2(
 p_clinic_id uuid,p_patient_id uuid,p_bed_id uuid,p_notes text default null,
 p_admission_type text default 'routine',p_referred_by text default null,
 p_provisional_diagnosis text default null,p_department text default null,
 p_consultant_name text default null,p_attendant_name text default null,
 p_attendant_relation text default null,p_attendant_phone text default null,
 p_admitted_at timestamptz default now()
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_room uuid; v_bed_number text; v_admission uuid:=gen_random_uuid(); v_no text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'IPD admission permission required'; end if;
 if p_admission_type not in ('routine','emergency','daycare','maternity','transfer') then raise exception 'Invalid admission type'; end if;
 if not exists(select 1 from public.patients p where p.id=p_patient_id and p.clinic_id=p_clinic_id and p.archived_at is null) then raise exception 'Patient not found in this clinic'; end if;
 select b.room_id,b.bed_number into v_room,v_bed_number from public.room_beds b
 join public.rooms r on r.id=b.room_id and r.clinic_id=b.clinic_id and r.active=true
 where b.id=p_bed_id and b.clinic_id=p_clinic_id and b.active=true for update of b;
 if v_room is null then raise exception 'Active bed not found in this clinic'; end if;
 if exists(select 1 from public.admissions a where a.clinic_id=p_clinic_id and a.bed_id=p_bed_id and a.status in ('admitted','transferred')) then raise exception 'This bed has already been allocated'; end if;
 v_no:='IPD-'||to_char(coalesce(p_admitted_at,now()) at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.admissions(id,clinic_id,patient_id,room_id,bed_id,admission_no,status,admitted_at,notes,admission_type,referred_by,provisional_diagnosis,department,consultant_name,attendant_name,attendant_relation,attendant_phone)
 values(v_admission,p_clinic_id,p_patient_id,v_room,p_bed_id,v_no,'admitted',coalesce(p_admitted_at,now()),nullif(trim(coalesce(p_notes,'')),''),p_admission_type,nullif(trim(coalesce(p_referred_by,'')),''),nullif(trim(coalesce(p_provisional_diagnosis,'')),''),nullif(trim(coalesce(p_department,'')),''),nullif(trim(coalesce(p_consultant_name,'')),''),nullif(trim(coalesce(p_attendant_name,'')),''),nullif(trim(coalesce(p_attendant_relation,'')),''),nullif(trim(coalesce(p_attendant_phone,'')),''));
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'create_admission','admission',v_admission::text,jsonb_build_object('admission_no',v_no,'patient_id',p_patient_id,'room_id',v_room,'bed_id',p_bed_id,'bed_number',v_bed_number,'admission_type',p_admission_type));
 return jsonb_build_object('id',v_admission,'admission_no',v_no,'patient_id',p_patient_id,'room_id',v_room,'bed_id',p_bed_id,'bed_number',v_bed_number,'status','admitted');
end $$;
revoke all on function public.create_clinic_admission_v2(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) from public,anon;
grant execute on function public.create_clinic_admission_v2(uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,timestamptz) to authenticated;

create or replace function public.transfer_clinic_admission_bed_v2(p_clinic_id uuid,p_admission_id uuid,p_to_bed_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_patient uuid; v_from_room uuid; v_from_bed uuid; v_to_room uuid; v_status text; v_bed_number text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Bed transfer permission required'; end if;
 if coalesce(length(trim(p_reason)),0)<3 then raise exception 'Transfer reason must be at least 3 characters'; end if;
 select a.patient_id,a.room_id,a.bed_id,a.status into v_patient,v_from_room,v_from_bed,v_status from public.admissions a
 where a.id=p_admission_id and a.clinic_id=p_clinic_id for update;
 if v_patient is null or v_status not in ('admitted','transferred') then raise exception 'Active admission not found in this clinic'; end if;
 select b.room_id,b.bed_number into v_to_room,v_bed_number from public.room_beds b join public.rooms r on r.id=b.room_id and r.clinic_id=b.clinic_id and r.active=true
 where b.id=p_to_bed_id and b.clinic_id=p_clinic_id and b.active=true for update of b;
 if v_to_room is null then raise exception 'Destination bed is not active in this clinic'; end if;
 if v_from_bed=p_to_bed_id then raise exception 'Patient is already assigned to this bed'; end if;
 if exists(select 1 from public.admissions a where a.clinic_id=p_clinic_id and a.bed_id=p_to_bed_id and a.status in ('admitted','transferred')) then raise exception 'Destination bed is already occupied'; end if;
 insert into public.admission_bed_transfers(clinic_id,admission_id,patient_id,from_room_id,to_room_id,reason,transferred_by)
 values(p_clinic_id,p_admission_id,v_patient,v_from_room,v_to_room,trim(p_reason),v_user);
 update public.admissions set room_id=v_to_room,bed_id=p_to_bed_id,status='transferred' where id=p_admission_id and clinic_id=p_clinic_id;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details)
 values(p_clinic_id,v_user,'transfer_ipd_bed','admission',p_admission_id::text,jsonb_build_object('from_room_id',v_from_room,'from_bed_id',v_from_bed,'to_room_id',v_to_room,'to_bed_id',p_to_bed_id,'to_bed_number',v_bed_number,'reason',trim(p_reason)));
 return jsonb_build_object('admission_id',p_admission_id,'patient_id',v_patient,'from_room_id',v_from_room,'to_room_id',v_to_room,'to_bed_id',p_to_bed_id,'bed_number',v_bed_number,'status','transferred');
end $$;
revoke all on function public.transfer_clinic_admission_bed_v2(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.transfer_clinic_admission_bed_v2(uuid,uuid,uuid,text) to authenticated;

comment on table public.room_beds is 'Individual physical beds belonging to a clinic room; allocation is linked to admissions.bed_id.';
comment on column public.admissions.admission_type is 'Routine, emergency, daycare, maternity or transfer admission.';
