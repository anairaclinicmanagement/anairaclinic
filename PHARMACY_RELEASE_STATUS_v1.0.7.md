# Anaira Clinic Pharmacy Store v1.0.7 — Search, Branding & A5 Print

## Changes
- Pharmacy status message no longer displays routine "Pharmacy data loaded..." counts as a banner. Pharmacy heading uses the configured store name and shows logo, address and phone when configured.
- Billing medicine field is searchable by typing product/medicine name; matching catalogue options are offered by browser datalist, and selecting a match fills the price from the earliest-expiry available non-expired batch.
- Pharmacy store settings now support logo URL or image upload (PNG/JPEG/WebP/SVG, max 2 MB), pharmacy address, phone, email, drug licence number, GSTIN, invoice prefix and default GST. Settings persist under the clinic's Supabase clinic_settings JSON.
- Latest pharmacy bill has a dedicated print-only invoice layout with pharmacy identity, logo, customer/UHID, invoice/date, item lines, GST, totals, paid/due and signature line.
- Shared print stylesheet uses A5 portrait page size and hides navigation/actions for cleaner printing throughout the app. For pharmacy invoice, only the dedicated invoice is printed; browser print dialog can save it as PDF.
- Existing pharmacy data, walk-in customer workflow and stock logic preserved.

## Verification
- `node scripts/verify-project.mjs`: PASS (35 routes, 31 migrations).
- TypeScript TSX transpile syntax checks: `app/pharmacy/page.tsx`, `app/opd/page.tsx`, `app/billing/page.tsx` — zero syntax diagnostics.
- Full `npm run typecheck`, production build, browser print/PDF visual verification and full E2E have not been run in this environment.
- GST legal treatment and invoice compliance must be verified by the clinic/accountant before live use.
