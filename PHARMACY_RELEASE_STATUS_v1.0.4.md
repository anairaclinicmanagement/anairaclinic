# Anaira Clinic Pharmacy Store v1.0.4 — Clinic/data loading fix

## Changes
- Pharmacy data loader now validates the active Supabase session and resolves clinic membership before querying product and batch records.
- If the saved clinic ID is stale and the signed-in user has exactly one active clinic membership, the app corrects the saved active clinic ID to that membership.
- Product/batch queries now report each Supabase error, empty results, or partial data with clinic ID and configured project URL host so the wrong project/RLS/clinic selection can be diagnosed rather than silently showing zeros.
- Pharmacy UI has one workspace navigation row: Overview, Products, Stock & expiry, Billing, Reports, Store settings.
- Existing database rows and demo stock are not deleted or overwritten by this code change.

## Database verification performed separately
- Intended Supabase project: `gdyvzvzmybbvufggxjty`.
- NH3 Clinic ID: `d7711acb-b3d3-4557-b4ba-e73cb9e028d7`.
- Database query returned 18 active product records, 18 inventory batches, and 377 units for this clinic.

## Checks
- `node scripts/verify-project.mjs`: PASS (35 routes, 29 SQL migrations).
- ZIP integrity: checked after packaging.
- TypeScript production build and browser E2E: not run in this environment; must be run locally after dependency install.
- If UI still reports zero, the page now displays the configured Supabase URL and clinic ID plus the exact query error/empty-state diagnostic.

## Setup
- Preserve the existing `.env.local`; do not replace it with an example or commit secrets.
- Ensure `NEXT_PUBLIC_SUPABASE_URL` points to the intended Supabase project and `NEXT_PUBLIC_SUPABASE_ANON_KEY` is valid.
