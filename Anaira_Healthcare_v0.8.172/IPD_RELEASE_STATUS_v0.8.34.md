# Anaira Healthcare v0.8.34 — IPD workflow update

## Included
- Added clinic-scoped, audited IPD bed-transfer history and an RPC that validates the destination room's capacity and clinic ownership.
- Added nursing-chart RPC with role checks and supported record types for vital signs, nursing notes, intake/output, medication administration, IV/injection, monitoring and shift handover.
- Updated IPD UI with bed transfer and nursing chart dialogs, saved nursing-record history, patient/UHID/mobile/admission search, and active/all/discharged/cancelled admission filters.
- Removed illustrative demo admission/bed rows from the live IPD page.
- Kept IPD invoices in the shared `invoices` register through the existing `create_ipd_invoice` workflow; shared Pharmacy remains at `/pharmacy`.

## Database
Migration: `20261026100000_anaira_ipd_nursing_and_bed_transfer.sql`.
Applied to the connected Anaira Healthcare Supabase project during this work; result returned success.

## Verification status
- Static project verification: PASS (`node scripts/verify-project.mjs`).
- TypeScript check / production build: NOT VERIFIED. Dependency installation did not complete in the execution environment; the local `node_modules` directory was incomplete.
- Browser end-to-end, live bed transfer, nursing record persistence, payment collection, and cross-role / cross-clinic tests remain required before describing this release as fully production-certified.
