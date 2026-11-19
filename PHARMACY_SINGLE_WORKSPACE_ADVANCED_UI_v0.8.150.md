# Anaira Healthcare v0.8.150 — Pharmacy Single Workspace

## Scope delivered
- Consolidated pharmacy operations into one `/pharmacy` workspace for clinic Admin/Owner and Pharmacist roles; no duplicate pharmacy route was introduced.
- Added a responsive operations header, role chip, refresh action, quick actions, KPI cards for catalogue size, on-hand units, estimated purchase value, low-stock products and expiry watch.
- Added a compact horizontally scrollable navigation for Overview, Medicine Catalogue, Stock & Expiry, Billing & Dispensing and Suppliers.
- Admin/Owner-only Reports and Admin Settings tabs are hidden from Pharmacist workspace and guarded in rendering.
- Existing clinic-scoped Supabase workflows remain in use for medicine master, FEFO stock receiving/dispensing, audited stock adjustment, prescription validation, walk-in customer, invoice/payment, supplier records and reports.
- Existing SQL FEFO dispensing sorts eligible batches by earliest expiry and blocks expired stock. No database migration is required for this UI-only release.

## Not represented as delivered
- Purchase orders, GRN with supplier invoice matching, purchase returns, sales returns/credit notes, barcode scanning, Schedule H1 statutory register, multi-counter shift cash closing, and controlled-drug workflows are not implemented by this release. These require schema, permission, audit and end-to-end workflow work; UI-only placeholders were not added.

## Validation
- `node scripts/verify-project.mjs` passed: 36 routes, 71 migrations, 21 required files.
- TypeScript and production build must still be run in the user's Windows environment; static verification is not a substitute.
