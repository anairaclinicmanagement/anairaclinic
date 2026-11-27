# Pharmacy Audit Trail Follow-up — 2026-11-26

Scope: Read-only inspection of the live Anaira Clinic Supabase project. No writes, migrations, ACL changes, or test records were created.

## Findings

### 1. Purchase return audit trail
- `public.create_pharmacy_purchase_return_from_store(...)` checks AAL2, authenticated user, and clinic role (`owner`, `admin`, `pharmacist`).
- It delegates the purchase-return creation to `public.create_pharmacy_purchase_return(...)`.
- The delegated function inserts:
  - `pharmacy_purchase_returns`
  - `pharmacy_purchase_return_items`
  - `stock_movements`
  - `pharmacy_supplier_ledger`
  - `audit_logs` with action `create_pharmacy_purchase_return`
- The store wrapper then decrements `pharmacy_store_stock` and writes a `pharmacy_inventory_ledger` entry.
- PostgreSQL function execution is transactional: an exception in the wrapper rolls back the delegated function's writes in the same transaction.
- Conclusion: purchase-return audit event is present through the delegated function; wrapper itself has no separate audit event describing store allocation. Consider whether the existing inner event plus store ledger is sufficient for operational audit.

### 2. Store stock-count submission
- `public.pharmacy_submit_store_stock_count(...)` checks AAL2, authenticated user, clinic role (`owner`, `admin`, `pharmacist`), active store, non-negative physical quantity, and that the batch exists in that store.
- It locks the store-stock row, creates a `pharmacy_stock_counts` row with status `pending`, and creates a `pharmacy_stock_count_items` row.
- Its function body does not insert into `audit_logs`.
- Read-only catalog inspection found no user-defined triggers on:
  - `pharmacy_stock_counts`
  - `pharmacy_stock_count_items`
  - `pharmacy_purchase_returns`
  - `pharmacy_purchase_return_items`
  - `pharmacy_store_stock`
  - `pharmacy_inventory_ledger`
  - `audit_logs`
- Conclusion: no submission audit event was found in the inspected database function or table triggers. This is a confirmed auditability gap in the current inspected path, not proof that no external application log exists.

### 3. Stock-count approval/rejection
- `public.pharmacy_approve_store_stock_count(...)` checks AAL2, authenticated user, and owner/admin role.
- It locks the pending count, changes status to `posted` or `rejected`, and records approver and timestamp.
- On approval it sets store quantity to physical quantity, adjusts central batch quantity by the variance (clamped at zero), and writes store inventory ledger and stock movement entries.
- It writes `audit_logs` action `pharmacy_store_stock_count_decision`.
- Conclusion: approval/rejection decision is auditable; initial submission is not visibly audited in the inspected database path.

### 4. Regression items before any production change
Use only isolated NH3 Clinic / Raghunath Hospital test data. Never write test data into PEHAL GREWAL.
- Submit count: verify pending header + item, no stock mutation, and assess expected audit event.
- Approve positive variance: verify store quantity, central batch quantity, ledger, stock movement, audit log.
- Approve negative variance: verify quantities and non-negative stock invariant.
- Reject: verify no stock mutation and decision audit event.
- Invalid batch/store/negative physical quantity: verify full rollback.
- Cross-clinic IDs: verify denial and no data leakage.
- Verify purchase-return wrapper rollback if store-level balance is insufficient.

## Status
- Cloud inspection: completed, read-only.
- Purchase-return delegated audit: confirmed in function source.
- Stock-count submission audit: missing in inspected function/trigger path.
- Stock-count decision audit: confirmed in function source.
- Runtime regression: pending.
- Migration or production change: not prepared/applied in this follow-up.
- PEHAL data: not touched.
- Anaira POS Local Server Docker DB: not touched.

## Recommended next implementation (requires approval)
Add a submission audit event to `pharmacy_submit_store_stock_count(...)` in a reviewed, additive migration or carefully reviewed function replacement, recording count ID/number, store, batch, system quantity, physical quantity, variance, notes (if policy permits), and actor. Preserve current authorization checks and tenant scope. Then run isolated regression tests before production deployment.
