# Anaira Healthcare v0.8.229 — Store Stock Count Submission Audit Event

Date: 2026-11-26

## Scope
Prepared a source-only migration to add an audit event to the existing store stock-count submission RPC. This package does not apply the migration to Supabase.

## Existing implementation inspected
Live cloud function source for `public.pharmacy_submit_store_stock_count(uuid, uuid, uuid, numeric, text)` was inspected read-only. It already enforces:
- AAL2 MFA.
- Non-null authenticated user.
- Clinic role: owner, admin or pharmacist.
- Active store belonging to the supplied clinic.
- Non-negative physical quantity.
- Batch stocked in the selected clinic/store, with the store-stock row locked.
- Creates a pending count header and count item.
- Does not directly write an audit log.

Read-only trigger inspection found no user-defined triggers on the inspected pharmacy stock-count and ledger tables. Approval/rejection RPC already writes `pharmacy_store_stock_count_decision`.

## Change prepared
New migration:
`supabase/migrations/20261126230000_pharmacy_stock_count_submission_audit.sql`

The migration uses `CREATE OR REPLACE FUNCTION` to preserve the existing RPC signature and add one `audit_logs` insert:
- action: `pharmacy_store_stock_count_submitted`
- entity_type: `stock_count`
- entity_id: generated count UUID
- details: count number, store ID, batch ID, system quantity, physical quantity and variance.

Free-text notes are intentionally excluded from the audit payload. The audit write is in the same database transaction as the count header and item, so a failed audit insert also rolls back submission rather than silently creating an unaudited count.

No table, column, policy, trigger or existing business record is dropped or backfilled.

## Safety and compatibility review
- Function signature and return JSON keys preserved.
- Existing authorization and validation checks preserved.
- Existing stock values are not changed during submission.
- No PEHAL data or POS Local Server Docker DB accessed.
- No migration applied.
- Production backup status not independently verified; therefore no production-safety claim is made.

## Required regression before production
Use only isolated NH3 Clinic / Raghunath Hospital test records:
1. Authorized pharmacist submits count; verify pending count header, item and one audit event.
2. Verify store and central stock remain unchanged on submission.
3. Owner/admin approves; verify stock adjustment, ledger, stock movement and decision audit.
4. Owner/admin rejects; verify no stock mutation and decision audit.
5. Reject non-AAL2, unauthorized role, inactive/cross-clinic store, cross-clinic batch and negative physical quantity.
6. Force/induce audit insert failure in a disposable test environment; verify entire submission transaction rolls back.
7. Confirm no duplicate event and verify audit payload contains no free-text notes/PHI.

## Status
- Read-only cloud function/trigger inspection: completed.
- Source migration prepared: completed.
- Static source validation: pending execution in this package build.
- Isolated runtime regression: pending.
- Production migration: NOT applied; explicit approval required.
- PEHAL GREWAL: untouched.
- Anaira POS Local Server Docker DB: untouched.

## Rollback
Before deployment, retain the current function definition from the migration review. If rollback is approved after deployment, restore that exact prior function definition using a separately reviewed rollback migration. Do not drop the function. No rollback SQL is executed by this package.
