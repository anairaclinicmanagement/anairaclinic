# Anaira Pharmacy ERP v0.8.158 — Release Notes

## Completed in this tranche
- Purchase Order approval/rejection controls are now exposed in the PO register for Owner/Admin roles and display approval state. Uses existing `pharmacy_approve_purchase_order` RPC.
- Approved Sales Returns can now be settled from the Pharmacy Returns screen with cash, UPI, card, bank transfer or credit note and transaction reference, using `pharmacy_settle_sales_return_refund`.
- Procurement workspace now loads supplier ageing, outstanding, reorder suggestions, expiry register and batch-traceable sales COGS/gross margin views.
- Cashier close reports cash collections separately from non-cash tender and deducts recorded cash refunds in the expected drawer amount.
- Unit conversion RPC is clinic/role guarded; reporting views use security-invoker semantics to preserve RLS.

## Supabase
- Applied and verified migrations: `anaira_pharmacy_reporting_ageing_cogs_reorder_unit_conversion_v083158` and `anaira_pharmacy_views_rls_cash_refund_reconciliation_v083158`.
- Added SQL source migration for reporting views.

## Still not complete (do not treat as production-certified)
- Multi-line PO editor in the UI; existing PO RPC accepts JSON arrays but current editor still creates one line at a time.
- Unit conversion is not yet wired into billing/dispensing quantity input and stock-unit normalization.
- Multi-store transfer ledger exists, but pharmacy dispensing and ward/OT issue flows still use central `inventory_batches`; store stock is not yet the single authoritative balance.
- COGS report is traceable only for invoices with recorded dispense allocations; gross margin excludes discounts/tax adjustments, refunds, wastage, and operating expenses.
- Cashier shift reconciliation currently uses payments and recorded cash refunds by cashier/time; no guaranteed payment-to-shift foreign-key assignment exists, so concurrent/multi-terminal shifts need E2E validation.
- Drug schedule register is an operational log, not legal compliance certification.
- Full Next.js production build, TypeScript project check, browser E2E, and live stock/refund transaction tests remain unverified.

## Checks
- `node scripts/verify-project.mjs`: PASS (36 routes, source migrations scanned).
- Pharmacy TSX transpilation diagnostics: 0.
- ZIP integrity: to be checked at packaging.
