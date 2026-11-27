# Anaira Healthcare — Phase 0C Migration Reconciliation Addendum
Date: 2026-11-26
Source package: v0.8.226
Supabase project: Anaira Clinic (`gdyvzvzmybbvufggxjty`)

## Read-only findings

- Source package contains 80 SQL migration files.
- Live Supabase migration history returned 117 applied records.
- Counts are not proof of missing migrations. Source and cloud version/name sequences differ materially.
- The source contains `001_initial_schema.sql`, which explicitly says it is for a NEW, DEDICATED Supabase project only. It must not be applied to the existing Anaira Clinic cloud project.
- The source contains `20261119160000_platform_admin_tenant_data_reset.sql`. It creates preview/reset RPCs. The reset RPC contains dynamic `DELETE FROM` operations scoped by clinic/category and requires platform-admin authorization plus exact clinic-name confirmation. This is still a destructive capability and must never be invoked against PEHAL GREWAL or production records as a test.
- The source contains several migrations with `DROP POLICY`, `DROP FUNCTION`, and other DDL. These require exact cloud/source mapping and dependency review before any execution.
- The live migration list includes applied versions `20261126091018` and `20261126091205`; source also contains later local files including `20261126190000`, `20261126193000`, `20261126193100`, `20261126193200`, and `20261126210000`. Their absence from the returned applied list means they are not recorded as applied in that snapshot; it does not prove they are safe to apply.
- No schema migration was applied during this reconciliation. No business rows were written or deleted.

## Verification performed
- `verify-phase0c-security-migration.mjs`: PASS after fixing its source verifier predicate.
- `verify-phase0c-migration-reconciliation.mjs`: PASS.
- `verify-project.mjs`: PASS (37 routes, 80 SQL migrations, 21 required files).
- ZIP integrity: PASS.

## Safety disposition
1. Do not run `001_initial_schema.sql` against the existing cloud project.
2. Do not invoke `platform_admin_reset_clinic_data` or test the tenant reset UI against PEHAL GREWAL.
3. Do not bulk-apply all local migrations or use migration count as a sync strategy.
4. Before applying any pending migration, compare its full SQL against live catalog/schema state, confirm whether its effects already exist, check FK/RLS/function dependencies, and produce a per-migration rollback/impact plan.
5. Test write workflows only against the approved NH3 demo tenant or a separately approved non-production database. No paid Supabase branch was created.

## Still unresolved
- Full one-to-one source migration ↔ cloud applied migration mapping.
- Definition/hash equivalence for cloud migrations whose names differ from source.
- Full dependency review for all `DROP` statements and the tenant-reset RPC.
- TypeScript/build/browser E2E and NH3 workflow certification.

## Protected resources
- PEHAL GREWAL production data was not used or modified.
- Anaira POS Local Server database was not accessed or modified.
