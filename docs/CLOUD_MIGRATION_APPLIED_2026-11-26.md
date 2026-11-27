# Anaira Healthcare v0.8.232 — Cloud Migration Applied

Date: 2026-11-26
Supabase project: Anaira Clinic (`gdyvzvzmybbvufggxjty`)
Region: ap-southeast-1
Project status at preflight: ACTIVE_HEALTHY

## Migration applied
Name: `pharmacy_stock_count_submission_audit`
Cloud migration version recorded by Supabase: `20261126174049`

The migration uses `CREATE OR REPLACE FUNCTION` for the existing function:
`public.pharmacy_submit_store_stock_count(uuid,uuid,uuid,numeric,text)`

It adds an audit row in the same transaction as count header/item creation:
- action: `pharmacy_store_stock_count_submitted`
- entity_type: `stock_count`
- entity_id: generated count UUID
- details: count number, store, batch, system quantity, physical quantity, variance
- free-text notes are not copied into the audit payload.

## Post-apply verification — live cloud
Supabase `list_migrations` returned the new row:
`20261126174049 | pharmacy_stock_count_submission_audit`

Live catalog query confirmed:
- Exact existing function signature retained.
- Owner remains `postgres`.
- SECURITY DEFINER remains true.
- `search_path` remains empty/pinned.
- Function source contains `pharmacy_store_stock_count_submitted`.
- Existing ACL remains: PUBLIC, anon, authenticated and service_role EXECUTE grants.

## Scope and safety
- One migration only was applied.
- No table, column, index, policy, trigger, patient, invoice, payment or stock record was directly changed by migration.
- Function body replacement is the intended change.
- No test RPC invocation was made; no test data was written.
- PEHAL GREWAL data was not touched.
- Anaira POS Local Server Docker DB was not accessed.
- No paid Supabase branch was created.
- No backup/restore operation was performed or claimed.

## Important ACL note
The existing function ACL still explicitly grants EXECUTE to PUBLIC and anon as well as authenticated and service_role. The migration did not harden this ACL. Existing function body requires AAL2 and an authenticated clinic role. A separate ACL review and regression plan is still required; do not claim anon access is safe solely because the function checks JWT claims.

## Pending runtime regression
Still required using disposable NH3 Clinic / Raghunath Hospital fixtures and an authorized AAL2 test user:
1. Submit count: pending header + item + exactly one audit event.
2. Verify stock unchanged during submission.
3. Approve positive and negative variance.
4. Reject and verify no stock mutation.
5. Invalid quantity/store/batch and cross-clinic denial.
6. Audit insert failure rollback.
7. Check inventory ledger, stock movement, and decision audit.

The rollback harness is included at:
`scripts/tests/pharmacy-stock-count-submit.rollback.sql`

It has not been executed against cloud because isolated disposable fixture IDs and test credentials were not available.

## Whole-project migration reconciliation
This deployment did not apply all source ZIP migrations. Cloud already had 117 migrations and historical source versions/names are not one-to-one with the ZIP's migration filenames. The new migration was applied as a single reviewed change. Remaining migrations must be reconciled one by one before any batch deployment.
