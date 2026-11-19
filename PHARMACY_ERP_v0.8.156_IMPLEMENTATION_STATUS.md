# Anaira Pharmacy ERP v0.8.156 — Inventory Controls Expansion

## Added in this source update
- Barcode/GTIN field in medicine master and barcode-aware catalogue search. USB/Bluetooth scanners that type into the focused search field can be used; no camera-based scanning is claimed.
- Clinic-scoped pharmacy sub-store master (Pharmacy, Ward, OT, ICU, Branch, Other).
- Audited batch stock transfer between created stores, with source quantity lock/check and stock transfer ledger.
- Physical stock count submission with Owner/Admin approval and stock adjustment posting.
- Cashier shift open/close with opening float, payment-collection reconciliation, counted cash and variance summary.
- Database tables/RPCs deployed to the connected Anaira Supabase project; migration list and new table presence verified.
- Existing PO, GRN, supplier ledger/payment voucher and purchase return workflows retained.

## Database migration
- `anaira_pharmacy_erp_inventory_controls_returns_shifts_v083156`
- `anaira_pharmacy_cashier_shift_payment_schema_fix_v083156`
- Target project: `gdyvzvzmybbvufggxjty` (Anaira Clinic connection).

## Still not complete / not production-certified
- Sales return/refund: tables are prepared, but invoice-item/batch allocation, approval/refund posting and original payment reversal UI/RPC are not complete.
- Unit conversion: conversion master table exists; conversion-aware dispensing, split packs, loose units and fractional stock deduction are not wired end-to-end.
- Multi-store: store master and transfer workflow are added, but existing central dispensing/GRN stock is not yet automatically allocated to a selected store. Opening balances need controlled initialization.
- Purchase-order maker/checker approval and GRN against a selected PO with partial receipt UI remain incomplete.
- Supplier ageing/running balance, credit-note settlement and accounting-grade GST ledger remain incomplete.
- Actual batch-linked COGS, margin, expiry loss, cash-vs-UPI split Z report and refund reconciliation need completion.
- Schedule H/H1/X register schema is present, but governed prescription capture, controlled access, retention and legal validation are not complete. This is not a compliance certification.
- Recall/quarantine, damage/write-off, maker-checker for all stock movements, offline-safe sync and full audit/security test suite remain outstanding.

## Verification
- `node scripts/verify-project.mjs`: PASS (36 routes; 73 existing source migrations).
- ZIP integrity: checked after packaging.
- Production build / TypeScript / browser E2E: NOT verified in this environment; prior attempt failed because `next` executable was not installed in node_modules.
- Database schema and migration presence verified. No live stock transfer/count/shift transaction was run against clinic stock; test in a non-production clinic before operational use.
