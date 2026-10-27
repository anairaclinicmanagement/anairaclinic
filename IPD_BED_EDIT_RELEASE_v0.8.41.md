# Anaira Clinic v0.8.41 — IPD Bed Edit

## Changes
- Added an **Edit bed** action to each active physical-bed row in IPD & Beds.
- Edit modal allows updating bed number, price per 12 hours, and active/inactive state.
- Saves changes to `public.room_beds`, scoped by the selected clinic and bed ID.
- Validates non-empty bed number and a non-negative price (maximum ₹10,000,000).
- Prevents deactivating an occupied bed.
- Refreshes the bed register after a successful save.
- Existing invoices are not silently recalculated when a bed price changes; the new rate applies to future estimates/invoices.

## Verification
- TypeScript TSX syntax transpilation: passed (0 parser diagnostics).
- Supabase schema migration: no new migration required; uses existing `room_beds.price_per_12_hours` column.
- Full Next.js production build and live browser/RLS workflow tests: not run in this patch environment.
