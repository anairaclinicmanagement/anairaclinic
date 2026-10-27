# Anaira Clinic v0.8.28 — A-to-Z Static Audit

## Executive result

**Status: NOT yet A-to-Z complete or production-certified.** This audit is based on the source ZIP only. The remote Supabase project was not accessible from this session, so live schema, credentials, RLS policies, real records, and save operations cannot be confirmed.

- App route pages inspected: 37
- Route pages containing Supabase client/database operations: 17
- Route pages with no direct Supabase operations in the page component: 20
- Static project verifier: PASS (the script itself states it does not replace typecheck, production build, database, browser E2E, or tenant-isolation tests).
- TypeScript check: BLOCKED by incomplete dependency installation in this environment (`TS2688` missing type definitions for estree, json-schema, json5, node, react, react-dom).
- Production build: BLOCKED because `next` executable was not runnable (`Permission denied`) after dependency installation did not complete.

## Route-by-route static matrix

| Route file | Direct Supabase ops | Select | Insert | Update | Delete | RPC | Static notes |
|---|---:|---:|---:|---:|---:|---:|---|
| `app/ambulance/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/appointments/page.tsx` | Yes | 3 | 1 | 0 | 0 | 0 | Needs runtime/E2E verification |
| `app/assets/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/billing/page.tsx` | Yes | 8 | 0 | 0 | 0 | 5 | Input placeholders: 4 (not inherently a defect) |
| `app/blood-bank/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/branches/page.tsx` | Yes | 2 | 1 | 0 | 0 | 0 | Needs runtime/E2E verification |
| `app/clinical-quality/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/consultation/page.tsx` | Yes | 1 | 0 | 0 | 0 | 1 | Needs runtime/E2E verification |
| `app/cssd/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/diet/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/documents/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/emergency/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/hospital-services/[module]/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/hospital-services/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/hr-payroll/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/insurance/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/ipd/page.tsx` | Yes | 5 | 1 | 4 | 0 | 3 | Demo/mock/sample markers: 9; Input placeholders: 3 (not inherently a defect) |
| `app/laboratory/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/login/page.tsx` | Yes | 4 | 0 | 0 | 0 | 0 | Input placeholders: 2 (not inherently a defect) |
| `app/opd/page.tsx` | Yes | 8 | 0 | 2 | 0 | 5 | Demo/mock/sample markers: 3; Input placeholders: 8 (not inherently a defect) |
| `app/operation-theatre/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/page.tsx` | Yes | 4 | 0 | 0 | 0 | 0 | Demo/mock/sample markers: 2 |
| `app/patient-portal/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/patients/page.tsx` | Yes | 1 | 0 | 0 | 0 | 1 | Demo/mock/sample markers: 1; window.confirm count: 2; Input placeholders: 2 (not inherently a defect) |
| `app/pharmacy/page.tsx` | Yes | 11 | 2 | 4 | 1 | 5 | Demo/mock/sample markers: 1; Uses localStorage; window.confirm count: 3; Input placeholders: 6 (not inherently a defect) |
| `app/prescriptions/page.tsx` | Yes | 4 | 0 | 0 | 0 | 2 | Input placeholders: 3 (not inherently a defect) |
| `app/procurement/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/radiology/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/referrals/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |
| `app/reports/page.tsx` | Yes | 8 | 0 | 0 | 0 | 0 | Needs runtime/E2E verification |
| `app/settings/page.tsx` | Yes | 1 | 0 | 0 | 0 | 0 | Demo/mock/sample markers: 1 |
| `app/setup/page.tsx` | Yes | 2 | 0 | 0 | 0 | 0 | Needs runtime/E2E verification |
| `app/staff/page.tsx` | Yes | 1 | 0 | 1 | 0 | 0 | Input placeholders: 7 (not inherently a defect) |
| `app/super-admin/page.tsx` | Yes | 7 | 0 | 2 | 1 | 8 | Input placeholders: 7 (not inherently a defect) |
| `app/support/page.tsx` | Yes | 2 | 1 | 0 | 0 | 0 | Needs runtime/E2E verification |
| `app/sync/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow; window.confirm count: 1 |
| `app/telemedicine/page.tsx` | No | 0 | 0 | 0 | 0 | 0 | No direct Supabase call found in page component; verify if static shell, shared service, or incomplete workflow |

## Highest-priority gaps to verify/complete

1. **Pages with no direct Supabase operations in their page component:** ambulance, assets, blood-bank, clinical-quality, cssd, diet, documents, emergency, hospital-services, hr-payroll, insurance, operation-theatre, patient-portal, procurement, laboratory, radiology, referrals, sync, telemedicine. These may use shared components or be static shells; inspect runtime and shared hooks before deciding each is incomplete.
2. **Demo-data risk:** `app/ipd/page.tsx`, `app/opd/page.tsx`, `app/patients/page.tsx`, `app/pharmacy/page.tsx`, `app/page.tsx`, and `app/settings/page.tsx` contain demo/mock/sample markers. Confirm demo data is not mixed into production lists or totals and cannot be accidentally billed.
3. **CRUD coverage:** Static counts show many data pages lack update/delete operations in the page component. Some workflows correctly use RPC or soft-cancel instead, so verify each business rule and audit trail before adding destructive deletion.
4. **Super Admin:** clinic profile edit depends on `platform_admin_update_clinic_profile`; apply `supabase/migrations/20261025193000_platform_admin_clinic_profile_edit.sql` to the actual configured Supabase project before testing Save. The code cannot apply this migration to a remote database from this chat.
5. **Build reproducibility:** rerun `npm ci` on a machine with working package registry access, then `npm run typecheck`, `npm run build`, and `npm run verify:static`. Fix any errors before deploying.
6. **Security:** test RLS/tenant isolation with at least two clinics and each role. Confirm unauthorized clinic IDs cannot be read or mutated, even by manually calling RPCs.
7. **Clinical safety:** validate admission, discharge, prescriptions, medication administration, lab results, billing/partial payments, refunds, and audit logs with synthetic test patients before production use.

## Acceptance checklist before calling it production-ready

- [ ] Fresh install from lockfile completes (`npm ci`)
- [ ] `npm run typecheck` passes
- [ ] `npm run build` passes
- [ ] All migrations apply in order to a staging Supabase project
- [ ] Each route has a documented read/create/edit/cancel/delete policy
- [ ] No demo rows leak into live clinic data
- [ ] Role-based access tested for every route and action
- [ ] Tenant isolation tests pass across two separate clinics
- [ ] Browser tests cover save → refresh → verify persisted data for every editable form
- [ ] Billing totals, partial payments, refunds, and invoice links reconcile
- [ ] Backups and restore tested before live rollout

## Super Admin modal fix included

`app/super-admin/page.tsx` renders the clinic editor as a fixed, centered overlay with internal scrolling. Save errors are rendered inside the modal. The matching database RPC migration is included but must be applied to the target Supabase project.

## Important boundary

This is an honest source audit, not a claim that every feature is complete. No live Supabase credentials/session were available, and the typecheck/build could not be completed in this environment. Do not deploy as production-certified until the checklist above passes.
