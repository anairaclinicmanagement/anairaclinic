# Anaira Clinic Pharmacy Store v1.0.5 — Advanced Workflow Update

## Included
- Added clinic-scoped Pharmacy Suppliers master (create, list, deactivate; supplier contact, GSTIN, address and notes).
- Added migration `20261025150000_pharmacy_advanced_suppliers_stock_audit.sql` for supplier records with RLS and a role/module-protected stock-adjustment RPC.
- Stock quantity correction now calls `adjust_pharmacy_batch`, requiring a reason and optional note, recording a stock movement and audit log. Sale-rate/supplier edit remains separately saved.
- Fixed OPD patient visit mapping to use `patientFromRow(pt).full_name` rather than reading an undeclared `full_name` property directly from the raw selected patient row.
- Kept pharmacy sections in one navigation row and retained existing billing, catalogue, FEFO dispensing, reports, GST settings, expiry/low-stock warnings and Supabase connection.
- Added a clearly labelled TEST DATA supplier to NH3 Clinic's connected Supabase project; replace its details before real purchasing.

## Verification
- `node scripts/verify-project.mjs`: PASS; 35 routes, 30 SQL migrations.
- Live Supabase migration applied successfully.
- NH3 Clinic supplier demo record verified.
- Full `npm ci`, TypeScript typecheck, Next.js production build and authenticated browser E2E were not completed in this environment because dependency installation timed out. Do not treat this release as production-certified until those checks pass.

## Notes
- Demo supplier is test data, not a real vendor.
- Supplier purchase orders, supplier payable ledger, purchase returns/credit notes, customer returns/refunds, barcode hardware integration and automated statutory GST determination are not claimed as completed by this release.
