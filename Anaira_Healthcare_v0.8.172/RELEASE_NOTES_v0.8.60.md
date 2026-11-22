# Anaira Healthcare Management System v0.8.60

## Clinical operations update
- Replaced the shared generic workflow-register screen for Operation Theatre, Emergency/Casualty and Ambulance with domain-specific forms and registers backed by their dedicated Supabase tables.
- Operation Theatre case creation validates that the selected patient matches an active IPD admission. An optional operation charge creates an IPD-linked invoice and invoice line in the same database transaction.
- Emergency/Casualty supports patient-linked triage, chief complaint, arrival mode, triage notes and visit disposition statuses.
- Ambulance supports vehicle/crew, patient, pickup/destination, dispatch time, notes and trip lifecycle status tracking.
- Removed the JSON-only details editor and generic integration disclaimer from the generic hospital work-item screen; operational notes are plain language.
- Reworded the diagnostic worklist's user-facing note to focus on clinical review/release.

## Database
Apply `supabase/migrations/20261028140000_real_ot_emergency_ambulance_workflows.sql` before using the new Operation Theatre workflow. The migration is additive and preserves existing data.

## Verification
- `node scripts/verify-project.mjs`: PASS (35 routes, 49 migrations, structural checks).
- `npm ci` did not finish within the available execution window; TypeScript, Next.js production build, live Supabase RPC, and browser end-to-end checks remain unverified.
- No claim is made that ambulance dispatch connects to GPS/telephony or that OT workflows replace clinical consent, anaesthesia charting, instrument tracking, or signed operative records.
