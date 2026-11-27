# Anaira Healthcare — Phase 0C Audit Report
Generated: 2026-11-26
Source archive: Anaira_Healthcare_v0.8.221_Phase0_Audit_Fixes.zip
Scope: source migration provenance + live Anaira Clinic Cloud security-function review.
Project: `gdyvzvzmybbvufggxjty` (Anaira Clinic, ACTIVE_HEALTHY, PostgreSQL 17.11.0.003).

## 1. Source archive verification
- ZIP integrity: PASS.
- Archive entries: 327.
- SQL migration files: 79.
- Distinct numeric migration versions: 77.
- Duplicate numeric migration version: `20261028220000` appears on three different SQL files:
- `['20261028220000_ambulance_trip_patient_assignment.sql', '20261028220000_ambulance_address_schema_compat.sql', '20261028220000_doctor_profile_without_login.sql']`

### Required remediation
Do not rename or apply these three files automatically. Supabase migration history is version-based; changing filenames alone may not correctly reconcile already-applied remote migrations. First compare each file's SQL effects with live schema/catalog and cloud migration history, then create a reviewed reconciliation plan. No destructive SQL is authorized.

## 2. Live cloud migration provenance
Read-only `list_migrations` returned 117 applied migration records.
The cloud history uses its own applied version identifiers; several source filenames have timestamps that do not match the cloud version/name records. Therefore a simple filename/count comparison is not a reliable missing-migration test.

### Candidate requiring explicit object-level comparison
- Source file: `20261126190000_pharmacy_generic_cash_walkin_customer.sql`
- Exact version/name was not present in the 117-row remote migration history returned during this audit.
- Status: **UNVERIFIED / candidate pending**, not conclusively unapplied. Search the live schema, function definitions, constraints and policies for its intended effects before deciding whether it needs to be applied.
- No migration was applied during this audit.

## 3. Live SECURITY DEFINER review
Read-only Security Advisor result:
- 14 SECURITY DEFINER functions are executable by `anon`.
- 105 SECURITY DEFINER functions are executable by `authenticated`.
- Auth leaked-password protection is disabled (one warning).

A read-only catalog inspection identified the 14 anon-executable functions. Twelve are ordinary RPC functions and two are trigger functions:
- RPCs with visible MFA AAL2 and clinic-role checks in their definitions: purchase return, discounted dispense, admission dispense, dispense, stock-count approval, stock-count submission, GRN receipt.
- `pharmacy_decide_sales_return_to_store` checks AAL2 but does not itself visibly check clinic role; it delegates to `pharmacy_decide_sales_return`. Verify the delegated function's authorization and caller context before deciding remediation.
- Trigger functions: `pharmacy_assign_payment_shift`, `pharmacy_assign_refund_shift`, `pharmacy_sync_batch_quantity_to_main_store`, `prevent_ipd_bed_double_allocation`, `release_ipd_room_allocation_beds_on_admission_change`, `validate_ipd_admission_package_scope` (six trigger functions; catalog results should be checked against trigger attachments; don't expose these as RPCs).
- The remaining ordinary RPC `receive_pharmacy_grn_to_store` contains user/role/MFA checks and tenant-scoped supplier/store/medicine validation.
- All inspected SECURITY DEFINER definitions had a configured `search_path`; most used empty search_path with schema-qualified references. `validate_ipd_admission_package_scope` uses `search_path=public` and needs a separate review.

**Important nuance:** the Advisor finding means EXECUTE is granted to `anon`; it does not by itself prove an unauthenticated caller can pass the functions' runtime authentication/MFA/role checks. Conversely, it is still unnecessary exposure for privileged RPCs and trigger routines. Do not bulk-revoke grants or change SECURITY DEFINER blindly.

### Recommended security remediation sequence
1. Inventory each function's exact signature, callers, attached triggers, ACL and dependent functions.
2. For trigger-only functions, confirm their trigger attachment and remove direct API exposure only after verifying the grant change will not affect trigger execution.
3. For RPCs, confirm the application calls them only with authenticated AAL2 sessions; verify `auth.uid()`, role, tenant and module gates.
4. Review `pharmacy_decide_sales_return_to_store` and delegated function together.
5. Test authenticated authorized and unauthorized users, anon calls, cross-clinic IDs, and trigger workflows in a safe non-production environment.
6. Only then prepare a narrow additive security migration; require explicit approval before production apply.
7. Enable leaked-password protection through Auth configuration after reviewing login impact and rollout communications.

## 4. Data and tenant protection
- This audit used read-only project metadata, migration listing, advisor results and catalog SELECTs.
- No patient/business rows were written or modified.
- No migrations were applied.
- PEHAL GREWAL production data was not used for tests.
- Anaira POS Local Server database was not accessed or touched.

## 5. Phase 0C status
| Work item | Status |
|---|---|
| Source ZIP integrity | COMPLETED |
| Duplicate migration-version detection | COMPLETED |
| Remote migration history read | COMPLETED |
| Source-to-cloud migration effect mapping | PENDING |
| 14 anon-executable SECURITY DEFINER function review | PARTIAL — signatures and guard indicators inspected |
| Trigger attachment and ACL dependency review | PENDING |
| 105 authenticated SECURITY DEFINER review | PENDING |
| Leaked-password protection remediation plan | PENDING |
| Production migration changes | NOT STARTED — approval required |

## 6. Next execution step
Perform exact source-to-cloud object-level reconciliation for the three colliding ambulance/doctor migration files and the `20261126190000` pharmacy walk-in migration. Then complete function-by-function security review. No production writes until evidence and rollback plan are ready and user approves.


## 7. Follow-up live ACL inspection and prepared hardening
A fresh catalog query confirmed all 14 anon-executable SECURITY DEFINER findings:
- 8 ordinary pharmacy RPCs: their definitions include AAL2 and clinic-role/module authorization checks (the return-to-store wrapper delegates to a separately guarded decision RPC).
- 6 trigger-only functions: attached to `payments`, `pharmacy_sales_return_refunds`, `inventory_batches`, `admissions` (two triggers), and `ipd_admission_packages`. Their ACLs inherited PUBLIC/anon/authenticated execution even though they are trigger routines.
- `validate_ipd_admission_package_scope` had `search_path=public`; its table reference is schema-qualified, so the prepared hardening pins it to an empty search_path.

A narrow migration has been prepared at:
`supabase/migrations/20261126210000_phase0c_security_definer_acl_hardening.sql`
It revokes PUBLIC/anon from the 8 RPCs while retaining authenticated execution, and revokes PUBLIC/anon/authenticated from the 6 trigger-only routines. It does not alter tables or business rows. A static verifier was added at `scripts/verify-phase0c-security-migration.mjs`.

**Not applied.** This is a production database ACL change and requires non-production validation plus explicit user approval before apply.

## 8. Cash walk-in migration live check
The cloud catalog check returned:
- `public.get_or_create_pharmacy_cash_customer(uuid)` does **not** currently exist.
- `public.patients.notes` and `public.patients.created_by` do exist.
This confirms the source migration's RPC is absent in the live cloud schema at the time of inspection. The migration's patient-row insert path has not been executed or tested. It remains a candidate pending review of the full patient constraints, RLS, trigger behavior, and safe NH3-only test plan. Do not apply automatically.


## 9. Correction to prepared ACL migration (important)
A signature-level review found that the earlier draft had hand-written RPC signatures that did not exactly match the live catalog. **Do not use that earlier draft.** The migration in this archive has been corrected to resolve each target function's OID and exact identity signature from `pg_proc` at execution time, verify exactly 8 RPCs and 6 trigger functions are found, and abort if the counts differ. It also filters trigger targets by `prorettype = trigger`. The static verifier was updated accordingly. This corrected migration remains NOT APPLIED and still requires non-production testing and explicit production approval.

## 10. Broader SECURITY DEFINER inventory (read-only aggregate)
Live catalog counts:
- `public`: 106 SECURITY DEFINER functions; 14 anon-executable; 105 authenticated-executable.
- `private`: 4 SECURITY DEFINER functions; none anon-executable; all 4 authenticated-executable.
- All 110 inspected functions have a pinned `search_path` configuration.
- In `public`, 101 definitions contain an `auth.uid()` or `auth.jwt()` context indicator; 94 contain one of the known clinic/platform role guard helper names; 8 contain `clinic_module_access`.
These are static indicators only, not proof of correct authorization. Function-by-function review of the full 110-function inventory remains open.


## 11. Migration collision and Cash Walk-in insert defect (live schema reconciliation)
Cloud migration history was queried directly:
- `20261028220000` is absent from cloud migration history.
- `20261126190000` is absent from cloud migration history.
Therefore the three source migrations sharing `20261028220000` were renamed to unique, unused versions:
  - `20261126193000_ambulance_address_schema_compat.sql`
  - `20261126193100_doctor_profile_without_login.sql`
  - `20261126193200_ambulance_trip_patient_assignment.sql`
This avoids the Supabase migration-version collision. The cloud history was checked for these new versions before packaging; none was present.

The live `public.patients` schema has `uhid text NOT NULL` with no default and no patient-table trigger. The original cash-customer migration omitted `uhid` from its INSERT, so its first insert would fail with a NOT NULL violation. The source migration is corrected to generate a clinic-unique-format UHID (`UHID-YYYYMMDD-XXXXXXXX`) using the generated patient UUID, and to insert the explicit UUID + UHID. The existing per-clinic advisory transaction lock and marker lookup remain.

Live schema constraints also confirm:
- `patients.clinic_id` is NOT NULL and references clinics.
- `patients.gender` accepts `unknown`.
- `patients.created_by` references auth.users with ON DELETE SET NULL.
- Existing patient RLS policies include clinic-role and AAL2 checks; the new RPC remains SECURITY DEFINER and includes auth.uid(), clinic role and pharmacy module checks.
- No patient triggers are installed in live cloud.
This is still source-only preparation: neither the cash-customer migration nor the renamed migrations have been applied to cloud. The cash-customer RPC was absent at inspection time.

## 12. Remaining validation
The cash-customer RPC still needs a non-production NH3 test for advisory-lock idempotency, repeated calls, correct clinic scoping, and compatibility with downstream invoices/dispensing. No test patient was inserted. Production approval is required before applying any pending migration.
