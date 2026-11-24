-- Mandatory MFA (AAL2) for every authenticated Data API and Storage access.
-- Apply only after deploying the matching login/AppShell MFA flow.
-- Restrictive policies compose with existing tenant/role policies; they do not replace them.
do $$
declare
  r record;
  v_definition text;
  v_patched text;
begin
  -- Every public base table in this project already has RLS enabled.
  for r in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r','p')
    order by c.relname
  loop
    if not (select relrowsecurity from pg_class where oid = format('%I.%I', r.nspname, r.relname)::regclass) then
      raise exception 'RLS must be enabled before enforcing MFA on %.%', r.nspname, r.relname;
    end if;
    execute format('drop policy if exists require_aal2_mfa on %I.%I', r.nspname, r.relname);
    execute format(
      'create policy require_aal2_mfa on %I.%I as restrictive for all to authenticated using ((auth.jwt() ->> ''aal'') = ''aal2'') with check ((auth.jwt() ->> ''aal'') = ''aal2'')',
      r.nspname, r.relname
    );
  end loop;

  -- Storage objects may contain patient scans, prescriptions and uploaded documents.
  if to_regclass('storage.objects') is not null then
    if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
      raise exception 'RLS must be enabled on storage.objects before enforcing MFA';
    end if;
    execute 'drop policy if exists require_aal2_mfa on storage.objects';
    execute 'create policy require_aal2_mfa on storage.objects as restrictive for all to authenticated using ((auth.jwt() ->> ''aal'') = ''aal2'') with check ((auth.jwt() ->> ''aal'') = ''aal2'')';
  end if;

  -- Views are otherwise commonly evaluated with the view owner's privileges.
  -- Make all public views use the caller's privileges so underlying RLS/AAL2 policies apply.
  for r in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v'
  loop
    execute format('alter view %I.%I set (security_invoker = true)', r.nspname, r.relname);
  end loop;

  -- SECURITY DEFINER RPCs bypass table RLS. Add an explicit AAL2 check to every
  -- public PL/pgSQL SECURITY DEFINER function callable as a normal function.
  -- Trigger functions are excluded because they execute as part of an already
  -- authorized table operation and cannot be invoked as ordinary RPC endpoints.
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public'
      and p.prosecdef = true
      and p.prokind = 'f'
      and l.lanname = 'plpgsql'
      and p.prorettype <> 'trigger'::regtype
  loop
    v_definition := pg_get_functiondef(r.oid);
    v_patched := regexp_replace(
      v_definition,
      E'(\\mBEGIN\\M)',
      E'\\1\n  IF (auth.jwt() ->> ''aal'') IS DISTINCT FROM ''aal2'' THEN\n    RAISE EXCEPTION ''MFA verification required'' USING ERRCODE = ''42501'';\n  END IF;\n',
      1, 1, 'i'
    );
    if v_patched = v_definition then
      raise exception 'Could not safely add MFA guard to SECURITY DEFINER function OID %', r.oid;
    end if;
    execute v_patched;
  end loop;
end $$;
