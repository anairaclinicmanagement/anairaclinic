# Anaira Healthcare v0.8.174 — IPD Admission Wizard

## Implemented
- Replaced the decorative four-step admission stepper with a working, state-driven wizard.
- Step 1: select an existing clinic patient by UHID; show patient name, age/gender, mobile, address and UHID.
- Step 2: capture admission type, department, consultant, referral, diagnosis, admission date/time, patient type, priority, arrival mode, emergency contact, remarks and attendant details.
- Step 3: load available physical beds from the existing clinic-scoped `room_beds` and `rooms` data; show availability counts and selected ward/room/bed/rate.
- Step 4: show a complete review of patient, admission, attendant and bed details before final confirmation.
- Added Previous/Next navigation, step validation, clickable completed steps, clear/reset behavior and a final-only submission button.
- The existing `create_clinic_admission_v2` RPC remains the only final submission path. It locks/rechecks the selected clinic bed and writes the admission/bed allocation atomically.
- Extra UI-only admission values (patient type, priority, mode of arrival, emergency contact and remarks) are retained in the existing admission notes field. No schema changes or destructive migrations were introduced.

## Verification
- TypeScript/TSX transpilation syntax diagnostics: PASS (0 diagnostics).
- `node scripts/verify-project.mjs`: PASS.
- Full `tsc --noEmit`, Next.js production build, authenticated browser E2E and live Supabase write tests were not run because project dependencies and live credentials are not present in this ZIP/runtime.
