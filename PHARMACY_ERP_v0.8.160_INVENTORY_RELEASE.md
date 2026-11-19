# Anaira Healthcare Pharmacy ERP v0.8.160 — Inventory Release

## Proper inventory foundation
- Store/location-aware stock balances per batch.
- Existing batch stock backfilled to the canonical Main Pharmacy store.
- Selected-store FEFO dispensing deducts both the global batch balance and the selected store balance in one database transaction.
- GRN receipts add quantities to the receiving store and write inventory ledger entries.
- Transfers write store-out/store-in movements and keep total batch stock unchanged.
- Store-specific stock count approval updates location balance and batch total with an audit/ledger record.
- Approved customer sales returns restore stock to the originating store.
- Purchase returns debit the selected store after supplier credit is posted.
- Dispense allocations retain store_id for audit and returns.
- Store inventory summary view reports units, batch count, cost/retail value and expiry quantities.

## Data reconciliation performed
- Canonical store is the existing `MAIN-PHARMACY` store.
- A duplicate `MAIN` store introduced during bootstrap was deactivated after reconciling store quantities.
- Live schema check after reconciliation: 18 inventory batches; batch total 359 units; store balance total 359 units; 0 mismatches.

## UI changes
- Store stock table and inventory movement ledger.
- Store selector for GRN receipt and dispensing.
- Transfers are sourced from the selected source store's batch balances.
- Physical count uses selected store's actual balance and the store-specific approval RPC.
- Purchase return and sales return use location-aware stock wrappers.

## Supabase migrations applied
- `anaira_pharmacy_authoritative_multi_store_inventory_v083160`
- `anaira_pharmacy_purchase_return_store_ledger_v083160`
- `anaira_pharmacy_main_store_dedup_and_stock_reconciliation_v083160`

## Still not certified
- Full production build and browser end-to-end tests.
- Ward/OT medication issue workflows from IPD/OT charts.
- Supplier invoice payment allocation and reconciliation against individual GRNs.
- Multi-branch inter-clinic stock transfers (cross-clinic transfers intentionally not allowed).
- Physical device barcode scanner testing.
- Statutory drug-register review by licensed pharmacist.
