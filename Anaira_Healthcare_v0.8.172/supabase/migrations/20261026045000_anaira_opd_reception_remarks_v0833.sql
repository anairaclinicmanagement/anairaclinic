alter table public.opd_visits add column if not exists remarks text;
comment on column public.opd_visits.remarks is 'Reception remarks captured with the OPD visit / parchi.';
