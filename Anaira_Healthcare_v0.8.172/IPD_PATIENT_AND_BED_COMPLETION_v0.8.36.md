# Anaira Healthcare v0.8.36 — IPD Patient Admission & Individual Beds

## Implemented in source
- Extended IPD admission capture: admission type (routine/emergency/daycare/maternity/transfer), date/time, referral source, provisional diagnosis, department, consultant, attendant details and notes.
- Individual physical bed inventory (`room_beds`) is loaded from Supabase. New room creation creates the configured number of individual bed slots.
- Admission now uses `create_clinic_admission_v2`, which validates the registered patient and selected active bed, checks clinic scope and prevents allocating an already occupied bed.
- Bed transfer now selects an individual available bed and uses `transfer_clinic_admission_bed_v2`, retaining the transfer audit record.
- IPD admissions table displays ward/room/bed and admission type/diagnosis; bed inventory lists individual bed occupancy.
- Room capacity edits add/remove available bed slots without allowing capacity to be lowered below occupied beds.
- Receptionist is explicitly allowed to create an admission through the new admission RPC.
- Shared pharmacy and shared invoice register routing remain unchanged.

## Supabase migrations applied
- `20261026110000_anaira_ipd_patient_admission_and_individual_beds.sql`
- `20261026111500_anaira_ipd_reception_admission_permission.sql`

Schema/RPC presence was verified in the connected Supabase project. At the time of checking, the connected project had zero rooms, bed slots and active admissions, so no existing IPD records were changed by the bed-slot backfill.

## Verification
- Static project verification passed.
- TypeScript/TSX syntax transpilation for `app/ipd/page.tsx` passed with zero parser diagnostics.
- Full `tsc --noEmit` could not run because the supplied `node_modules` is incomplete (missing type definition packages); `npm install` timed out in this environment.
- Production build and browser end-to-end workflows are not certified by this package. Validate using an authenticated clinic owner/admin and receptionist account before production use.
