# Anaira Healthcare v0.8.69 — Active Clinic Data Loading Fix

## Root cause addressed
The Ambulance and Billing pages read `anaira-clinic-active-id` directly and queried records before confirming that the authenticated user had an active membership in that clinic. A stale or mismatched saved clinic ID therefore resulted in empty lists despite records being present in Supabase.

## Changes
- Ambulance / Clinical Operations resolves the authenticated user's active `clinic_members` record before loading patient, vehicle, trip, emergency, and theatre data. It preserves a valid selected clinic; if there is exactly one membership, it safely selects that clinic.
- Billing resolves active membership before loading invoices, patients, diagnostic catalogue and unbilled ambulance trips, and surfaces query errors.
- Laboratory queue now queries paid orders and order items separately instead of relying on a nested relation select, and reports which query failed.
- No patient, trip, invoice, or payment data was reset or modified by this patch.

## Supabase audit
Read-only audit of project `gdyvzvzmybbvufggxjty` confirmed NH3 Clinic has 1 ambulance vehicle, 1 ambulance trip, 9 lab orders and 9 lab order items. The ambulance trip is `HP 34 B 9584`, currently dispatched, with no patient and no invoice. Existing ambulance RPCs and diagnostic update RPC are present.

## Verification
`node scripts/verify-project.mjs` passes (35 routes, 54 migrations). TypeScript/production build and authenticated browser E2E were not available in this environment; do not represent those as passed.
