# Anaira Healthcare v0.8.221 — Phase 0 Source Audit

Audit date: 2026-11-26
Input: `Anaira_Healthcare_v0.8.221_AI_Stock_Salt_Capture.zip`
Audit scope: ZIP/source inspection and repository static verification only.
No Supabase production connection, schema query, migration execution, patient-data mutation, or browser E2E was performed.

## 1. Integrity and repository baseline

- ZIP entries: 323
- ZIP integrity: PASS (`ZipFile.testzip()` returned no corrupt member)
- App Router route files found: 40 (includes API routes and dynamic route)
- SQL migration files: 79
- SQL table definitions detected across migrations: 94
- SQL function definitions detected across migrations: 77
- `CREATE POLICY` statements detected: 187
- `CREATE TRIGGER` statements detected: 11
- `node scripts/verify-project.mjs`: PASS
  - Script reports 37 routes and 79 migrations; it checks 21 required files.
  - Its own output explicitly says this does not replace TypeScript, production build, database, browser E2E, or tenant-isolation tests.

### Version discrepancy — must resolve
- ZIP filename says v0.8.221.
- Root directory inside ZIP is `Anaira_Healthcare_v0.8.205`.
- `package.json` version is `0.8.208`.
- Recent feature notes in the ZIP refer to v0.8.219–v0.8.221.
- Do not infer the deployable version from filename alone. Confirm the actual release/version source before next release.

## 2. Existing application routes

The source contains these routes:

`/`, `/pharmacy`, `/setup`, `/ipd`, `/settings`, `/sync`, `/consultation`, `/hospital-services`, `/assets`, `/appointments`, `/telemedicine`, `/procurement`, `/patient-portal`, `/prescriptions`, `/blood-bank`, `/clinical-quality`, `/super-admin`, `/branches`, `/laboratory`, `/hr-payroll`, `/insurance`, `/ambulance`, `/emergency`, `/reports`, `/cssd`, `/operation-theatre`, `/staff`, `/login`, `/diet`, `/support`, `/radiology`, `/documents`, `/doctors`, `/opd`, `/patients`, `/referrals`, `/billing`, `/api/auth/mfa/recover`, `/api/pharmacy/purchase-ocr`, `/hospital-services/[module]`.

This is a substantial existing HIS footprint. Presence of a route does not certify a complete workflow.

## 3. Super Admin — existing implementation found

`app/super-admin/page.tsx` contains UI sections for:
- Clinic / Hospital registration and editing.
- Facility types, specialties and enabled modules.
- Platform users.
- Platform audit logs.
- Clinic / hospital registry.
- Per-clinic module access.
- Platform settings.
- Subscription plans.
- Platform feature flags.
- Support tickets.
- Clinic / Hospital Data Reset.
- Backup & recovery status.

SQL objects include platform admin, platform audit, feature flags, platform settings, platform usage and backup metadata tables, plus RPCs for clinic provisioning, plans, module overrides, status, users, reset preview/reset and dashboard functions.

### Critical gap: true plugin runtime not found in executable source
A source search across `.ts`, `.tsx`, `.js`, `.jsx` and `.sql` files found no healthcare plugin registry/runtime implementation. The only relevant Sidebar reference says navigation follows plan/plugin changes, but the implementation reads subscription plans, module overrides and feature flags. No distinct plugin manifest, dependency graph, install/upgrade lifecycle, runtime registry, plugin migrations registry or plugin-specific permission manifest was identified.

Conclusion: the current product has a **module entitlement / feature-flag control plane**, not yet a verified extensible plugin platform. Preserve this system and evolve it; do not build a parallel plugin system.

## 4. Admin and role implementation found

`app/settings/page.tsx` has sections for:
- Clinic / Hospital profile.
- Facility profile.
- Logo and document branding.
- OPD parchi print settings.
- OPD & Registration.
- IPD, Wards & Beds.
- Pharmacy & Stock.
- Laboratory.
- Billing & Payments.
- Doctors & Staff.
- Radiology / RIS.
- OT & Surgery.
- Emergency / Casualty.
- Blood Bank.
- Procurement & Suppliers.
- Assets & Maintenance.
- Departments & Services.
- Branches & Workspaces.
- Reports & Analytics.
- Document Centre.
- Sync & Recovery.
- Support Centre.

`app/staff/page.tsx` loads `staff_profiles` scoped by `clinic_id`, creates staff via the `clinic-create-staff` Edge Function and supports role updates. `components/AppShell.tsx` has a hard-coded `rolePaths` route allowlist and aliases hospital_admin, clinic_admin and managing_director to admin.

Observed role path examples: owner, admin, doctor, radiology_technician, xray_technician, ultrasound_technician, ct_mri_technician, nurse, pharmacist, lab_technician, receptionist, accountant, staff, plus aliases.

### Admin/RBAC gaps to validate and address
- The application route map is role-string based and largely hard-coded.
- This is not yet evidence of a complete configurable permission matrix with organization, facility, department and store scopes.
- Sidebar visibility and AppShell route allowlists must be checked against server/API/RPC authorization for every protected operation.
- Branch membership and branch-scoped staff authorization are not established merely by creating a branch.
- Organization Owner / Facility Admin / Department Head / Store Manager distinctions are not fully evidenced by the current route map.
- Need a complete role-to-action matrix and direct unauthorized API/RPC tests.

## 5. Multi-facility architecture — partial foundation exists

The database includes:
- `clinics`
- `clinic_branches`
- `clinic_members`
- `clinic_module_overrides`
- `clinic_plans`
- `clinic_subscriptions`
- `staff_profiles`

Migration `20261028120000_multi_facility_types_and_brand_cleanup.sql` adds `clinics.facility_types`, backfills it from `clinic_type`, and permits a clinic/hospital record to declare multiple facility types.

Many operational tables include `clinic_id`; selected tables also include `branch_id`.

### Critical architecture gap
The current source is primarily a **clinic-as-tenant model with branches**. The inspected migration does not introduce a first-class `organizations → facilities → departments → operational units` hierarchy. Multiple facility types on one `clinics` row do not by themselves model a hospital and separately located satellite clinic as independent facilities with independent workflows, settings, staffing, billing and stock.

Do not immediately add new tenant tables. First map existing clinic, branch and facility semantics, foreign keys, RLS and data. Then design a backward-compatible organization/facility layer and migration mapping.

## 6. Database / security observations

The migration corpus contains substantial existing schema and security work:
- Clinic membership and role helpers.
- Subscription and module access checks.
- Tenant policies and hardening migrations.
- Atomic workflow RPCs for patient registration, OPD, admission, billing, pharmacy dispensing/receiving and related workflows.
- Platform admin RPCs and audit tables.
- MFA AAL2 enforcement migration dated 2026-11-24.

Important migration review points:
1. `20261124190000_enforce_mfa_aal2_for_authenticated_access.sql` adds restrictive AAL2 policies to all public tables and storage objects, and patches public PL/pgSQL SECURITY DEFINER functions. Confirm the matching MFA enrollment/login/recovery flow and production rollout status before treating it as active and safe.
2. `20261119160000_platform_admin_tenant_data_reset.sql` is a tenant data reset capability. Review its exact allowlist, preview/confirmation safeguards, backup proof and audit behaviour before any use. Do not execute it during this project.
3. `20261124150000_platform_users_clinic_memberships_and_root_admin_protection.sql` contains a hard-coded protected root-admin UUID. Confirm intended account mapping through secure administrative review; never expose credentials.
4. The migration files are source definitions only. Their presence does not prove they have been applied to the linked Supabase project.
5. Counted SQL object definitions are lexical counts across migrations, not counts of live database objects or a complete dependency graph.

## 7. Module inventory — source presence vs certification

| Area | Source evidence | Audit status |
|---|---|---|
| Patients / UHID | patient tables and `/patients` | Existing; E2E unverified |
| OPD / appointments / consultation / prescriptions | routes, tables, RPCs and migrations | Existing; E2E unverified |
| IPD / beds / nursing / discharge / packages | routes, tables, RPCs and migrations | Existing; E2E unverified |
| Pharmacy / procurement / OCR | `/pharmacy`, OCR API, medicine/inventory/purchase schema and recent migrations | Existing; E2E unverified |
| Laboratory | `/laboratory`, lab tables and RPCs | Existing; E2E unverified |
| Radiology | `/radiology`, radiology orders | Existing; E2E unverified |
| OT / emergency / ambulance | routes, tables and workflow migrations | Existing; E2E unverified |
| Blood bank / CSSD / diet | routes, tables and migrations | Existing; E2E unverified |
| Insurance / HR / assets | routes and related tables | Existing; E2E unverified |
| Telemedicine / referrals / patient portal | routes and related schema | Existing; E2E unverified |
| CRM | referrals and feedback evidence; full CRM pipeline not established | Partial / needs detailed audit |
| Plugin runtime | no dedicated executable registry found | Missing / not verified |
| Organization-level multi-facility hierarchy | clinic + branch + multi-type foundation | Partial; major gap |
| Fine-grained scoped RBAC | membership roles + hard-coded route allowlist | Partial; major gap |
| Real backup/restore execution | backup metadata and status UI | External orchestrator required; not proven |
| Offline sync | offline tables, queue and UI | replay engine and conflict lifecycle need verification |

## 8. Priority gap list

P0 — before broad architecture changes:
1. Confirm exact release version and source ZIP provenance.
2. Obtain a fresh live Supabase schema/RLS/RPC inventory and migration-history comparison.
3. Verify MFA enrollment, AAL2 login, recovery and service-role/edge-function boundaries.
4. Review tenant reset RPC and backup/restore controls.
5. Build route/API/RPC-to-role authorization matrix.
6. Trace branch_id coverage and actual branch-scoped workflows.

P1 — foundation:
7. Design organization → facility → department → operational unit → store/ward hierarchy using existing clinic/branch records as mapped legacy entities.
8. Define a shared module entitlement contract and evolve current plans/overrides/feature flags into plugin manifests/runtime without duplication.
9. Implement facility/department/store-scoped membership and permission grants.
10. Add safe migration/backfill, reconciliation and rollback plan.

P2 — modules and certification:
11. Finish OPD/IPD/Pharmacy/LIS/RIS/OT/Emergency/Billing end-to-end regression.
12. Validate single clinic, polyclinic, nursing home, hospital + satellite clinic, and multi-hospital group scenarios.
13. Validate auditability, offline sync, backup restore, performance and clinical safety controls.

## 9. What was not done
- No code feature was changed.
- No SQL migration was created or applied.
- No Supabase production data was read or modified.
- No live RLS test was run.
- No Next.js production build or TypeScript check was run.
- No browser workflow or clinical end-to-end test was run.
- No production certification is claimed.

## 10. Next required input/action
Proceed with a read-only live Supabase audit using the project's authorized connector, after confirming access and the intended project. Compare live migration history, tables, columns, constraints, indexes, functions, triggers, views and RLS policies against the ZIP. Do not apply migrations or reset data. Then produce a reconciled Existing / Missing / Broken / Applied / Not Applied report before designing Phase 1.


# LIVE SUPABASE AUDIT ADDENDUM — 2026-11-26

Project selected from the existing `Anaira clinic` Supabase connection:
- Project: `Anaira Clinic`
- Project ref: `gdyvzvzmybbvufggxjty`
- Region: `ap-southeast-1`
- Database engine: PostgreSQL 17
- Project status: `ACTIVE_HEALTHY`

Only metadata/catalogue and security-advisor queries were run. No patient rows, clinical notes, invoices or other personal business records were selected. No DDL/DML, migration apply, reset, or configuration change was performed.

## Live migration history

- Supabase migration history reports **117 applied migrations**.
- Latest applied migration version: `20261126091205` (`fix_pharmacy_main_store_stock_sync_trigger`).
- The supplied ZIP contains **79 SQL migration files**.
- These two counts cannot be treated as a simple 38-migration pending list because source migration timestamps/names do not consistently map one-to-one to the live migration ledger. A full migration provenance reconciliation is required before generating or applying any migration.
- The supplied ZIP includes a migration named `20261126190000_pharmacy_generic_cash_walkin_customer.sql`, while the live ledger includes the pharmacy stock sync fixes at `20261126091018` and `20261126091205`. Confirm source provenance and whether the supplied ZIP was created before or after those changes.

## Live schema and RLS

- Public base tables: **111**.
- Public base tables with RLS enabled: **111**.
- Public base tables with RLS disabled: **0**.
- Policies in `public`: **532**, covering **111** tables.
- Live catalogue includes extensive pharmacy tables: stores, store stock, inventory ledger, goods receipts, purchase orders/returns, transfers, stock counts, cashier shifts, supplier ledger/ageing, COGS and returns. This is a materially richer live schema than a superficial reading of the initial migrations would suggest.
- Clinic/branch scoping columns exist across many business tables; the live database query found `clinic_id` widely used and `branch_id` on selected workflows. No `organization_id` or `facility_id` columns were found in the inspected public schema column inventory. This confirms the current model remains clinic/branch-centric rather than the proposed organization/facility hierarchy.

## Live functions and security findings

- Public PL/pgSQL SECURITY DEFINER functions: **106**.
- Of these, **100** function definitions contain an AAL2 check.
- The remaining six are trigger-returning functions (`pharmacy_assign_payment_shift`, `pharmacy_assign_refund_shift`, `pharmacy_sync_batch_quantity_to_main_store`, `prevent_ipd_bed_double_allocation`, `release_ipd_room_allocation_beds_on_admission_change`, `validate_ipd_admission_package_scope`); they are trigger functions rather than ordinary business RPC endpoints. Confirm they are only invoked as triggers and have no unsafe direct call path.
- Supabase Security Advisor reports **14** `anon_security_definer_function_executable` findings. Catalogue inspection separates this into eight non-trigger business RPCs and six trigger functions with broad/default execute grants.
- Eight non-trigger SECURITY DEFINER business RPCs have PUBLIC/anon EXECUTE exposure:
  1. `create_pharmacy_purchase_return_from_store`
  2. `dispense_pharmacy_sale_discounted_from_store`
  3. `dispense_pharmacy_sale_for_admission_from_store`
  4. `dispense_pharmacy_sale_from_store`
  5. `pharmacy_approve_store_stock_count`
  6. `pharmacy_decide_sales_return_to_store`
  7. `pharmacy_submit_store_stock_count`
  8. `receive_pharmacy_grn_to_store`
- Inspection of these eight definitions found an AAL2 check at the beginning of each. Most also contain explicit clinic-role checks. `pharmacy_decide_sales_return_to_store` delegates the authorization decision to `pharmacy_decide_sales_return`; that delegated function and the exact permission chain need a focused review.
- AAL2 checks reduce practical unauthenticated access, but broad PUBLIC/anon EXECUTE grants are still an unnecessary exposure and trigger a Supabase security warning. Recommended next step is to review exact callers and then revoke EXECUTE from `PUBLIC` and `anon` for RPCs intended only for authenticated users, while preserving `authenticated` and `service_role` grants as required. Do not apply this change until the app callers and trigger dependencies are verified.
- Security Advisor also reports **105** SECURITY DEFINER functions callable by authenticated users. This is not automatically a vulnerability; each function must enforce caller identity, tenant scope, module entitlement and role/action permissions.
- Six trigger functions did not contain AAL2 text; this is expected for some trigger functions, but they must remain non-callable as public RPCs and only execute through their owning table triggers.

## Other Security Advisor finding

- **Leaked Password Protection is disabled** in Supabase Auth. Enable after reviewing auth settings and rollout impact; this is a configuration change and was not performed.

## Current live audit conclusion

Positive:
- Project is healthy.
- RLS is enabled on all 111 public base tables.
- There are 532 public policies across all 111 tables.
- AAL2 checks are present in 100/106 public PL/pgSQL SECURITY DEFINER function definitions.
- Recent pharmacy stock sync migrations are recorded as applied in the live migration history.

High-priority follow-up:
1. Resolve 117 live migrations vs 79 ZIP migration files with a provenance-aware comparison.
2. Review/revoke unnecessary PUBLIC/anon EXECUTE on the eight business RPCs and ensure trigger functions are not directly callable.
3. Review all 105 authenticated SECURITY DEFINER RPCs by role, clinic scope, module entitlement and action.
4. Enable leaked-password protection after assessing authentication UX.
5. Complete organization/facility/department/store data model design and migration mapping.
6. Confirm MFA rollout and recovery end-to-end; presence of migration and AAL2 guards alone does not prove every user has enrolled or can recover safely.

No production changes were made during this live audit.
