# Anaira Clinic Pharmacy Store v1.0.3 — UI and build fixes

## Changes
- Removed duplicate Pharmacy navigation row. The remaining single navigation includes Overview, Products, Stock & expiry, Billing, Reports, and Store settings.
- Fixed OPD build type error by deriving patient display name through `patientFromRow()` rather than reading `full_name` from raw patient query rows.
- Added visible pharmacy data-load diagnostics for medication and batch query errors, empty results, and partial results. Messages include selected clinic ID to help identify wrong active clinic selection or project/permissions mismatch.
- Preserved existing Supabase wiring, stock records, demo inventory, and migrations.

## Checks
- `node scripts/verify-project.mjs`: PASS (35 routes, 29 migrations).
- ZIP integrity: verified after packaging.
- `npm ci --ignore-scripts`: timed out in this environment; no local TypeScript compiler was available, so full `tsc` and production build were not run here.
- Live browser E2E not run. The visible diagnostics should identify why a user's browser gets empty pharmacy query results.

## Important
No `.env.local` or secrets are included. Keep the existing local `.env.local` when extracting/merging.
