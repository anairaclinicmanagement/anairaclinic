# Anaira Healthcare — Phase 0 source audit & safe fixes
Audit date: 2026-11-26
Source archive: `Anaira_Healthcare_v0.8.221_Phase0_Audit_Pack(1).zip`
Internal root: `Anaira_Healthcare_v0.8.205`
`package.json` version: `0.8.208`

## Executive result

**Status: Phase 0 source audit partially complete; release is not production-certified.**
The archive contains substantial existing healthcare workflows, but also verifiable release-governance defects and major architectural gaps. One audit-tool defect was repaired. No business workflow, clinical data, database migration or live Supabase state was changed.

## 1. Inventory inspected

- ZIP entries: 326
- App Router page files: 37
- SQL migration files: 79
- Supabase Edge Functions: 2 (`clinic-create-staff`, `platform-create-clinic`)
- API route handlers: 2 (`/api/auth/mfa/recover`, `/api/pharmacy/purchase-ocr`)
- Main module routes include patients, doctors, appointments, OPD, consultation, prescriptions, billing, IPD, pharmacy, laboratory, radiology, OT, emergency, ambulance, blood bank, CSSD, diet, insurance, HR/payroll, assets, procurement, telemedicine, referrals, patient portal, reports, settings and Super Admin.
- Existing static verifier: `scripts/verify-project.mjs`.

## 2. Existing vs required vs missing vs broken

| Area | Existing in source | Gap / status |
|---|---|---|
| Patients / UHID | Patient page, registration RPC migration, duplicate guard | Source exists; live E2E and cross-facility identity unverified |
| OPD / appointments / consultation / prescriptions | Pages, print flows, linked orders and RPC migrations | Source exists; complete regression unverified |
| IPD / wards / beds / nursing / discharge | Pages, room/bed allocation, billing and package migrations | Source exists; complete regression unverified |
| Pharmacy / procurement / purchase OCR | Pharmacy page, purchase OCR API, GRN workflow and recent features | Source exists; provider secrets/live OCR and E2E unverified |
| LIS / RIS / OT / emergency / ambulance | Pages and workflow migrations | Source exists; end-to-end and integration certification pending |
| Blood bank / CSSD / diet / insurance / HR / assets | Routes and supporting schema evidence | Presence only; full workflows unverified |
| Super Admin | Clinic/tenant controls, plans, module overrides, flags, users, audit and backup metadata | Existing control plane; plugin lifecycle not established |
| Plugin runtime | No dedicated executable manifest registry/runtime/dependency/install/upgrade lifecycle found in source search | Missing / not verified |
| Organization → facility hierarchy | Clinic tenant, branches, multiple facility types on clinic record | Partial; not equivalent to independent organization/facility hierarchy |
| Scoped RBAC | Membership roles and hard-coded AppShell route allowlist | Partial; action-level org/facility/department/store authorization matrix missing |
| Offline | Offline schema/cache/queue source | Replay, conflict resolution and recovery lifecycle unverified |
| Backup / DR | Backup status/metadata UI evidence | Actual backup and restore drill not proven |
| CRM | Some referrals/feedback evidence | Full CRM pipeline not established |
| Production build / Typecheck | Scripts declared in package.json | Not run: dependencies are not included in archive; `node_modules` absent |

## 3. Confirmed defects and safe code change

### 3.1 Static verifier false-PASS defect — FIXED
In the supplied `scripts/verify-project.mjs`, the script printed PASS and called `process.exit(1)` before the final doctor-directory and staff-profile-link assertions. Those checks were therefore unreachable and could not affect the result.

**Change made:** moved all assertions before the final decision; final PASS is emitted only after all checks pass.

### 3.2 Duplicate Supabase migration versions — DETECTED, NOT AUTO-RENAMED
Three distinct SQL files share the same version prefix `20261028220000`:
- `20261028220000_ambulance_address_schema_compat.sql`
- `20261028220000_ambulance_trip_patient_assignment.sql`
- `20261028220000_doctor_profile_without_login.sql`

Supabase migration version identifiers must be unique. The verifier now fails on this collision instead of reporting a misleading PASS.

**Why not auto-rename:** live migration history already has 117 applied records, while this ZIP has 79 files. Renaming versions without exact migration-ledger/source reconciliation could cause already-applied SQL to be replayed or cause history divergence. Keep blocked until each migration is matched to the live ledger and its effects are verified.

### 3.3 Version provenance mismatch — OPEN
- Archive label: `v0.8.221`
- Internal folder: `v0.8.205`
- `package.json`: `0.8.208`

Do not publish this as a single verified release version until provenance is resolved.

## 4. Previously observed live cloud metadata (read-only audit context)

The linked Anaira Clinic cloud project was previously inspected read-only:
- Project ref: `gdyvzvzmybbvufggxjty`; status ACTIVE_HEALTHY.
- 117 applied migrations; latest observed `20261126091205`.
- 111/111 public base tables had RLS enabled; 532 policies.
- 106 public PL/pgSQL SECURITY DEFINER functions.
- Security Advisor showed 14 anon-executable SECURITY DEFINER findings and 105 authenticated SECURITY DEFINER findings; these require function-by-function authorization review, not bulk revocation.
- The inspected public schema was clinic/branch-centric; `organization_id` / `facility_id` were not found in the inspected column inventory.
- Leaked Password Protection was disabled.
- No production data or schema was modified as part of this ZIP audit.

These are prior read-only observations, not fresh verification from this source-only run.

## 5. Validation executed in this run

| Check | Result |
|---|---|
| ZIP extraction / integrity | PASS |
| Source inventory | PASS |
| Original static verifier | Returned PASS, but had unreachable assertions |
| Patched static verifier | Correctly FAILS on the three-way migration version collision |
| TypeScript check | NOT RUN — dependencies absent |
| Next.js production build | NOT RUN — dependencies absent |
| Browser / API E2E | NOT RUN |
| Live Supabase migration/RLS tests | NOT RUN in this run |
| Data writes / migrations applied | NONE |

## 6. Work still required, in safe order

### P0 — resolve before any schema rollout
1. Reconcile the three duplicate migration versions against the exact live migration ledger and source SQL hashes.
2. Reconcile all 79 source migrations against 117 live applied migration records; never infer pending migrations by subtraction.
3. Resolve archive/root/package version provenance.
4. Run `npm ci`, `npm run typecheck`, `npm run build` in a controlled project workspace.
5. Verify MFA enrollment, login, AAL2 recovery and all protected API/RPC boundaries.
6. Review the tenant-reset RPC and verify backup evidence; never execute reset during audit.
7. Review every SECURITY DEFINER function and its EXECUTE grants/caller authorization; do not bulk revoke.

### P1 — architecture foundation
8. Map current `clinics` and `clinic_branches` to the target organization/facility hierarchy.
9. Design additive organization/facility/department/operational-unit/store relations with backfill, reconciliation and rollback.
10. Evolve current module entitlement/feature-flag system into a manifest/runtime lifecycle; do not create a parallel plugin system.
11. Implement action-level RBAC with org/facility/department/store scope and direct API/RPC denial tests.

### P2 — complete module workflows
12. Run module-by-module UI/API/database/RLS/role/validation/regression/responsive/print tests.
13. Complete CRM, offline replay/conflict lifecycle, backup/restore orchestration and analytics gaps.
14. Validate single-clinic, multi-doctor, nursing-home, standalone hospital, satellite clinic, diagnostic centre, independent pharmacy and multi-hospital group scenarios.

## 7. Preservation and change log

- Preserved all existing business pages, APIs, migrations and data definitions.
- Modified only `scripts/verify-project.mjs`.
- No SQL migration created or applied.
- No cloud database writes.
- No patient/clinical/billing/pharmacy business records accessed or modified.
- No Anaira POS local database/container touched.
- No `.env` or secret values included or printed.

## 8. Rollback

To revert the only source change, restore the original `scripts/verify-project.mjs` from the pre-change ZIP. No database rollback is needed because no database change was made.
