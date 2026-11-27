# ANAIRA HEALTHCARE — NEXT SESSION CONTINUATION PROMPT

Continue the existing Anaira Healthcare project using:
- Latest supplied source baseline: `Anaira_Healthcare_v0.8.221_AI_Stock_Salt_Capture.zip`
- Read `PHASE_0_SOURCE_AUDIT_v0.8.221.md` first.
- User's master requirements are in `Pasted text(20261126-155400).txt` / Master Continuity & Implementation Prompt.

## Current verified state
- ZIP integrity PASS; 323 entries.
- Static verifier PASS (`node scripts/verify-project.mjs`).
- 79 SQL migration files, 40 App Router route files.
- Existing substantial OPD, IPD, Pharmacy, LIS, RIS, OT, Emergency, Ambulance and other module source exists.
- Super Admin currently has plans, module overrides, feature flags, settings, users, audit, support and backup metadata controls.
- Dedicated plugin manifest/runtime was not found in executable source; evolve the existing module entitlement system rather than creating a duplicate.
- Current tenant model is clinic-centric with branches and multiple facility types; a first-class organization/facility/department/store hierarchy is not yet evidenced.
- Admin roles are partly hard-coded in AppShell; full scoped RBAC is not yet evidenced.
- ZIP name v0.8.221, internal root v0.8.205 and package.json version 0.8.208 disagree. Resolve release provenance.
- 79 migration files in ZIP do not prove live application. Production Supabase state is unverified.
- No code or database change was made during Phase 0.

## Live Supabase audit — completed read-only, follow-up required
Correct linked project confirmed: `Anaira Clinic`, ref `gdyvzvzmybbvufggxjty`, status ACTIVE_HEALTHY.

Verified live metadata:
- 117 migrations applied; latest `20261126091205` (`fix_pharmacy_main_store_stock_sync_trigger`).
- 111 public base tables; RLS enabled on all 111; zero public base tables without RLS.
- 532 policies across 111 tables.
- 106 public PL/pgSQL SECURITY DEFINER functions; 100 definitions contain AAL2.
- Security Advisor: 14 anon-executable SECURITY DEFINER findings; eight are non-trigger business RPCs and six are trigger-returning functions. The eight business RPCs contain AAL2 checks, but PUBLIC/anon EXECUTE grants are unnecessary exposure and require caller review before tightening.
- Security Advisor: 105 authenticated SECURITY DEFINER function warnings; review each authorization contract rather than assuming every warning is a vulnerability.
- Leaked Password Protection is disabled.
- Live schema has clinic_id widely and branch_id selectively; organization_id/facility_id were not found in the inspected public column inventory.
- ZIP contains 79 SQL migration files. Do not infer 38 pending migrations; reconcile timestamps and names against migration ledger first.
- No production changes were made.

## Next task — Phase 0C: focused security and migration provenance review
1. Review exact definitions and grants for the eight non-trigger RPCs listed in the live audit addendum.
2. Review trigger-returning functions to ensure they are only invoked by their table triggers and not exposed as callable RPC endpoints.
3. Review the 105 authenticated SECURITY DEFINER RPCs for caller identity, tenant scope, module entitlement and role/action checks.
4. Reconcile 117 live migration ledger entries against 79 source migration files using exact names, definitions and source history; do not apply anything.
5. Verify MFA enrollment/login/recovery and backup/restore operational status.
6. Produce a proposed least-privilege grants migration and test plan, but do not apply it until the user approves.
7. Then propose the organization/facility hierarchy using current clinics/branches as mapped legacy entities and an additive/backfill/rollback plan.

Preserve all existing patient, clinical, billing, pharmacy and audit data. No production DDL/DML until explicit approval.


## Latest supplied ZIP audit update — 2026-11-26
Source ZIP: `Anaira_Healthcare_v0.8.221_Phase0_Audit_Pack(1).zip`
Audit report: `PHASE_0_IMPLEMENTATION_AUDIT_v0.8.221.md`

Verified source inventory: 326 ZIP entries, 37 App Router pages, 79 SQL migrations, 2 API routes, 2 Edge Functions.
One source-only code fix: `scripts/verify-project.mjs` now evaluates all assertions before PASS/FAIL. It also detects duplicate Supabase migration version prefixes.
Current verifier result is FAIL (correctly): three SQL files use version `20261028220000`:
- `20261028220000_ambulance_address_schema_compat.sql`
- `20261028220000_ambulance_trip_patient_assignment.sql`
- `20261028220000_doctor_profile_without_login.sql`

Do not rename or apply these migrations until matching each to the live migration ledger and source definitions. The archive/root/package versions still disagree (0.8.221 / 0.8.205 / 0.8.208).
No SQL migration or cloud data was changed. Anaira POS local database was not touched.
Next: resolve migration provenance, then install dependencies in controlled workspace and run TypeScript/build; continue read-only function/grant review; then design Phase 1 organization/facility hierarchy and plugin/RBAC foundation. No production DDL/DML without explicit approval.


## Latest verified continuation — Phase 0C (2026-11-26)
Continue from `PHASE0C_MIGRATION_SECURITY_AUDIT_2026-11-26.md`.
The source contains 79 SQL migrations with three files sharing version `20261028220000`; do not rename/apply blindly. Cloud history returned 117 applied migrations, but source-to-cloud effects are not yet mapped. The cloud Security Advisor reports 14 anon-executable and 105 authenticated-executable SECURITY DEFINER functions plus leaked-password protection disabled. Function-level review is partial; no production migration was applied. Next: compare the three colliding migrations and `20261126190000_pharmacy_generic_cash_walkin_customer.sql` against live schema/catalog/history, then review trigger attachments and function ACLs. Preserve PEHAL GREWAL; do not touch Anaira POS Local Server DB. Do not bulk revoke grants or modify production without explicit approval.


## Phase 0C follow-up status (2026-11-26)
Live catalog confirms 14 anon-executable SECURITY DEFINER functions: 8 guarded RPCs (AAL2 + clinic role/module checks; the sales-return wrapper delegates to guarded RPC) and 6 trigger-only routines. Trigger attachments were inspected. Prepared but did NOT apply `supabase/migrations/20261126210000_phase0c_security_definer_acl_hardening.sql`: remove PUBLIC/anon from 8 RPCs, remove PUBLIC/anon/authenticated from 6 trigger routines, pin validate_ipd_admission_package_scope search_path to empty. Static verifier added. Cloud `get_or_create_pharmacy_cash_customer(uuid)` is absent, while patients.notes and patients.created_by exist; review constraints/RLS/triggers and plan NH3-only test before migration. Next: test prepared ACL migration in non-production, request explicit approval before production apply, review remaining 105 authenticated-executable SECURITY DEFINER functions, and reconcile the duplicate ambulance migration version. No DB writes/migrations applied.


Important correction: the earlier ACL migration draft used hand-copied signatures and must not be applied. The latest ZIP replaces it with a corrected dynamic pg_proc OID/identity-resolution migration that verifies exactly 8 RPCs and 6 trigger functions before applying ACL changes. It remains unapplied. Live catalog has 106 public + 4 private SECURITY DEFINER functions; all 110 have pinned search_path; public: 101 contain auth context indicators, 94 known role-helper indicators, 8 module guard indicators. These are static indicators, not proof of correct authorization. Continue full function-by-function audit and test migration in non-production before any production approval.


Phase 0C latest: cloud migration history has no 20261028220000 version; three colliding source migrations were renamed to unique 20261126193000 (ambulance schema compatibility), 20261126193100 (doctor profile without login), 20261126193200 (ambulance trip patient assignment). Cloud history also lacks 20261126190000 cash walk-in migration. Live patients.uhid is NOT NULL, has no default and no trigger; original migration would fail on insert. Source migration corrected to generate explicit UHID-YYYYMMDD-UUID8 plus patient UUID; no cloud apply or patient write. Existing gender allows unknown, notes/created_by exist; patient RLS has role/AAL2 policies; function checks auth.uid, clinic role and pharmacy entitlement. Next validate script and full migration drift; plan NH3-only nonproduction test. Keep PEHAL and Anaira POS Local DB untouched.
