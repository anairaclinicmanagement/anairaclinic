# Anaira Healthcare Master Progress Checklist

Legend: [x] verified in supplied source; [~] partial/source presence only; [ ] pending; [?] live/runtime unverified.

## Phase 0 — Source audit
- [x] ZIP integrity
- [x] Route inventory
- [x] Migration inventory
- [x] SQL source object inventory
- [x] Super Admin source review
- [x] Admin/settings source review
- [x] Sidebar and AppShell role-route review
- [x] Existing module presence inventory
- [x] Static verifier
- [x] Live Supabase schema and migration-history comparison (117 applied vs 79 ZIP migration files; provenance reconciliation pending)
- [~] Live RLS/RPC/trigger metadata verification (111/111 tables RLS enabled; 532 policies; RPC grants need review)
- [ ] Backup/restore proof

## Architecture
- [~] Clinic tenant and branch foundation exists
- [~] Multiple facility types on clinic record exists
- [ ] First-class organization/facility/department/operational-unit/store model
- [ ] Cross-facility patient identity and authorized record sharing
- [ ] Facility/department/store scoped RBAC
- [ ] Plugin manifest/runtime/dependency lifecycle

## Existing module source
- [~] Patient and UHID
- [~] OPD, appointment, consultation, prescription
- [~] IPD, bed, ward, nursing, discharge
- [~] Pharmacy, procurement, purchase OCR
- [~] Laboratory and radiology
- [~] OT, emergency, ambulance
- [~] Blood bank, CSSD, diet
- [~] Billing, insurance, HR, assets
- [~] Telemedicine, referrals, patient portal
- [ ] End-to-end regression certification for all modules

## Security and operations
- [~] Membership roles and route allowlists
- [ ] Complete action-level permission matrix
- [ ] Live tenant isolation tests
- [ ] MFA/AAL2 rollout verification
- [ ] Reset RPC safety review
- [ ] Verified backup and restore drill
- [~] Offline queue/schema exists
- [ ] Offline replay/conflict lifecycle certification

## Release governance
- [ ] Resolve ZIP/root/package version mismatch
- [ ] Maintain migration log with actual applied status
- [ ] Maintain known issues and regression evidence
- [ ] Update this checklist and NEXT_SESSION_PROMPT.md after every phase

## Live security follow-ups
- [~] 8 non-trigger SECURITY DEFINER business RPCs have PUBLIC/anon EXECUTE grants; all 8 show AAL2 guards, but grants should be tightened after caller review
- [~] 6 trigger-returning SECURITY DEFINER functions lack AAL2 text; verify trigger-only invocation and remove broad direct execute if appropriate
- [ ] Review 105 authenticated SECURITY DEFINER RPC grants and authorization checks
- [ ] Enable Supabase leaked-password protection after rollout review
- [ ] Reconcile live migration history (117) against ZIP source migrations (79)


## 2026-11-26 — Latest supplied ZIP audit addendum
- [x] Extracted and inventoried latest supplied Phase 0 Audit Pack (326 ZIP entries).
- [x] Confirmed 37 App Router pages, 79 SQL migration files, 2 API route handlers and 2 Supabase Edge Functions.
- [x] Fixed static verifier control-flow bug: all assertions now execute before PASS/FAIL.
- [x] Added duplicate Supabase migration-version detection to static verifier.
- [!] Static verifier now correctly FAILS because three migration files share version `20261028220000`; do not rename until reconciled with live migration ledger.
- [!] Release provenance mismatch remains: archive v0.8.221 / root v0.8.205 / package 0.8.208.
- [ ] TypeScript/build/E2E pending (dependencies absent in ZIP environment).
- [ ] Plugin runtime, organization/facility hierarchy and fine-grained scoped RBAC remain major architecture gaps.
- [ ] CRM full workflow, offline replay/conflict lifecycle and backup/restore drill remain unverified.
- [ ] No SQL migration applied; no production data changed.


## Phase 0C — Migration Provenance & Security (2026-11-26)
- [x] Source ZIP integrity verified (327-entry audit-fix archive).
- [x] 79 SQL migration files / 77 distinct numeric versions identified.
- [x] Three files collide on migration version `20261028220000`; reconciliation pending.
- [x] Live cloud history read: 117 applied migrations; no migration applied in this audit.
- [x] Security Advisor reviewed: 14 anon-executable SECURITY DEFINER functions; 105 authenticated-executable SECURITY DEFINER functions; leaked-password protection disabled.
- [ ] Map source migration effects to live schema and cloud history.
- [ ] Review trigger attachments, function ACLs, nested authorization and all privileged RPCs.
- [ ] Prepare narrow security migration only after testing and approval.

Safety: PEHAL GREWAL production records untouched; Anaira POS Local Server database untouched.


## Phase 0C follow-up — 2026-11-26
- [x] Re-inspected live ACLs for all 14 anon-executable SECURITY DEFINER functions.
- [x] Confirmed 8 are RPCs with AAL2/clinic role checks; 6 are trigger-only routines.
- [x] Confirmed trigger attachments and identified `validate_ipd_admission_package_scope` search_path hardening.
- [x] Prepared narrow ACL migration `20261126210000_phase0c_security_definer_acl_hardening.sql` (NOT APPLIED).
- [x] Added static verifier `scripts/verify-phase0c-security-migration.mjs`.
- [x] Confirmed cloud cash-customer RPC absent; patient columns `notes` and `created_by` exist.
- [ ] Test ACL migration on non-production copy and obtain explicit production approval.
- [ ] Review full 105 authenticated-executable SECURITY DEFINER function set.
- [ ] Review cash-customer migration constraints/RLS/triggers before NH3-only test.


## Phase 0C — ACL migration signature correction
- [x] Rechecked exact live function identities and trigger return types.
- [x] Replaced hand-written signatures with dynamic OID/identity resolution and expected-count guards (8 RPC + 6 trigger functions).
- [x] Updated static verifier.
- [ ] Non-production execution test and explicit production approval still required.
- [ ] Complete function-by-function review of all 110 SECURITY DEFINER functions.


## Phase 0C — migration reconciliation follow-up
- [x] Verified cloud migration history does not contain colliding source version 20261028220000.
- [x] Renamed three colliding source migrations to unique versions 20261126193000/193100/193200.
- [x] Verified cloud history does not contain cash-customer migration version 20261126190000.
- [x] Found and corrected cash-customer INSERT defect: live patients.uhid is NOT NULL, has no default and no trigger; migration now explicitly generates UHID.
- [x] Added static migration reconciliation verifier.
- [ ] Execute verifier in the project environment.
- [ ] Test cash-customer function in non-production NH3 clone; no patient test row inserted in production.
- [ ] Reconcile complete pending migration set against cloud by exact version/name/content.
