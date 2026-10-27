# Anaira Healthcare Pharmacy Store v1.0.2

## Included
- Existing Supabase-backed medicine/product catalogue, product categories, SKU/HSN/unit/manufacturer fields, per-item GST, active/deactivate workflow.
- Batch-wise inventory, expiry tracking, stock receipt, quantity/rate/supplier editing, and guarded deletion of empty batches only.
- Existing pharmacy dispensing RPC integration, patient/prescription selection, payment status and invoice summary.
- Pharmacy workspace navigation: Overview, Products, Stock & expiry, Billing, Reports, Store settings.
- Added date-filtered pharmacy sales report, totals for invoice value/collections/outstanding, inventory valuation, supplier aggregation from existing stock batches, CSV exports for sales and inventory.
- Settings stored in clinic_settings and scoped to the active clinic.

## Validation
- `node scripts/verify-project.mjs`: PASS (35 routes, 29 migrations).
- npm dependency installation timed out in this environment; TypeScript typecheck, Next production build, browser E2E and authenticated live sales-report verification were not run.
- Sales report uses existing invoice_items rows where item_type = 'pharmacy', then fetches the associated clinic invoices. Supplier report is an aggregation of existing batch supplier names, not a full supplier ledger.

## Not certified / remaining enterprise workflows
- Supplier master with payable ledger, purchase orders and supplier invoices.
- Returns/refunds and credit notes with safe stock restoration.
- Full stock-movement ledger and reason-coded adjustment workflow.
- Separate CGST/SGST vs IGST calculation and accountant-approved invoice compliance.
- Barcode scanner workflow, prescription-only medicine enforcement across all product types, and automated daily report delivery.
- Do not treat demo batches/products as real pharmacy stock. Confirm product data, batch and expiry before dispensing.
