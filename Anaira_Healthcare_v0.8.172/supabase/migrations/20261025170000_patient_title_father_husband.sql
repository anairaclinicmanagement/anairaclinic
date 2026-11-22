-- Patient demographics required on OPD registration slips.
-- Tenant scope remains enforced by the existing patients RLS policies on clinic_id.
alter table public.patients add column if not exists title text;
alter table public.patients add column if not exists father_name text;
alter table public.patients add column if not exists husband_name text;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.patients'::regclass and conname='patients_title_allowed') then
    alter table public.patients add constraint patients_title_allowed check (title is null or title in ('Mr.','Miss','Mrs.','Ms.','Master','Dr.')) not valid;
  end if;
end $$;
alter table public.patients validate constraint patients_title_allowed;
