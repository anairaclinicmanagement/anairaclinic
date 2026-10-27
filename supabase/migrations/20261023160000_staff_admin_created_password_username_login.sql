-- Staff accounts are provisioned by the clinic owner/admin; email is optional.
alter table public.staff_profiles add column if not exists username text;
create unique index if not exists staff_profiles_username_global_unique on public.staff_profiles(lower(username)) where username is not null and length(trim(username)) > 0;
create index if not exists staff_profiles_phone_lookup_idx on public.staff_profiles(regexp_replace(coalesce(phone,''),'[^0-9]','','g')) where phone is not null;
