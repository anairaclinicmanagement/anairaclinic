# Anaira Healthcare v0.8.31 — OPD Reference Screen Update

## Implemented
- Added OPD workspace styling based on the supplied reference: navy/blue clinical theme, pastel multi-colour navigation cards, styled forms/tables, responsive layout, quick actions, today's OPD summary and recent-patient shortcuts.
- Added reception fields for patient address, referral source and visit type (New / Follow-up / Emergency).
- Added visit type and referral source to the OPD queue table.
- Kept existing patient/visit creation RPC, role gating, doctor queue status actions, same-parchi doctor notes, linked prescription/lab order workflow, registration fee settings and print flow.
- Added idempotent database migration for `opd_visits.referred_by` and `opd_visits.visit_type`.

## Supabase
- Project: `gdyvzvzmybbvufggxjty` (Anaira Healthcare).
- Migration `anaira_opd_reference_fields_v0831` was applied successfully.
- Verified the two columns exist in `public.opd_visits`.

## Verification
- `node scripts/verify-project.mjs`: PASS (static structure and migration safety).
- TypeScript/production build/browser E2E were not run because this ZIP has no `node_modules`; no production build success is claimed.
- Real role-specific browser flows and print preview should still be tested in the deployed app.
