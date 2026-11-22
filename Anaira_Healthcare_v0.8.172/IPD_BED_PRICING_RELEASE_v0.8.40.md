# Anaira Healthcare v0.8.40 — IPD Bed Tariff

## Included
- Added `room_beds.price_per_12_hours` with a non-negative numeric constraint and clinic-scoped index.
- Add Room / room-capacity modal asks for a required bed price per 12-hour block in INR.
- Every physical bed generated for the room receives that tariff; editing the room tariff updates its bed slots.
- Bed register, room capacity table and admission bed selector show the tariff.
- IPD bill modal shows an estimate based on the assigned bed's tariff and elapsed 12-hour blocks, rounded up; user can copy the estimate into the invoice amount.
- Supabase migration included at `supabase/migrations/20261026123000_anaira_ipd_bed_price_per_12_hours.sql`.

## Billing rule
`charge = bed tariff per 12 hours × ceil(stay duration / 12 hours)`, with at least one block for a nonzero/invalid duration fallback. This is an estimate shown before the user creates an invoice; it is not silently billed. Existing beds default to ₹0 until an authorized clinic admin edits the room/bed tariff.

## Verification limitations
Supabase migration was applied and the constraint was verified. Static verification can be run locally. TypeScript, production build and browser end-to-end tests were not run in this environment because project dependencies are not installed.
