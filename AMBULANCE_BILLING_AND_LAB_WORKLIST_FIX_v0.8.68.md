# Anaira Healthcare v0.8.68 — Ambulance/Billing + Lab Worklist

## Fixes
- Ambulance register shows the existing trip regardless of patient assignment and supports assigning an active patient in the same clinic.
- Billing worklist fetches all unbilled ambulance trips with a positive charge, including legacy trips missing patient_id.
- Billing lets authorised staff assign the patient to a trip, then offers invoice creation only after the trip is completed and linked to a patient.
- Patient assignment is handled by a clinic-scoped SECURITY DEFINER RPC, validates patient and trip tenant, blocks changes after invoicing, and writes an audit log.
- Preserves the v0.8.67 Lab Technician clinic-resolution and patient lookup fallback.

## Database migration required
Apply `supabase/migrations/20261028220000_ambulance_trip_patient_assignment.sql` in the connected Supabase project before using patient assignment. No existing records were modified by packaging this update.

## Verification
Static project verifier and ZIP integrity should be run. A full production build/browser E2E requires the project's installed dependencies and a signed-in test account.
