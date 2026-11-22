# Anaira Healthcare v0.8.26 — Super Admin audit and changes

## Changes in this package
- Added an **Edit clinic** action to the Super Admin Clinic & hospital registry.
- Edit form supports clinic name, clinic type, contact email/phone, facility model, specialties, and enabled modules.
- Added an authenticated, database-side `platform_admin_update_clinic_profile` RPC. It checks `private.is_platform_admin()`, validates values, updates only the selected clinic profile, and writes clinic/platform audit events.
- Extended `platform_admin_dashboard()` to return profile fields required by the registry: email, phone, facility model, specialties, enabled modules, and clinic profile.
- Registry now shows a profile-completeness indicator and counts of configured specialties/modules.
- Existing clinics, patient records, membership, subscription, and module override data are not deleted.

## Supported clinic/facility models in the current schema
- Single clinic / single location (`single_site`)
- One clinic with multiple branches (`multi_branch_clinic`)
- Multi-clinic group / chain (`multi_clinic_network`)
- Single hospital (`hospital`)
- Multi-hospital group (`multi_hospital_network`)
- Polyclinic (`polyclinic`)
- Diagnostic centre (`diagnostic_centre`)

## Supported clinic types
The provisioning schema/function allows general OPD/medicine, dental and dental specialties, eye/optometry, skin/dermatology/cosmetology, pediatrics/neonatology, gynecology/obstetrics/fertility, orthopedics/sports medicine, physiotherapy, neurology, cardiology, diabetology/endocrinology, gastroenterology, pulmonology, nephrology/urology, ENT, psychiatry/psychology, oncology/rheumatology/geriatrics/pain management, Ayurveda/Homeopathy/Unani/Siddha/Naturopathy, diagnostic/pathology/radiology/imaging/dialysis/vaccination, urgent care, polyclinic, nursing/maternity/day-care/rehabilitation/fertility centres, eye/dental hospitals, general/multi-specialty/super-specialty hospitals, and other.

## Supabase connection / existing clinic completeness
- Source code uses `@/lib/supabase` and reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`; clinic provisioning also requires the deployed `platform-create-clinic` Edge Function with `SUPABASE_SERVICE_ROLE_KEY` configured server-side.
- This package can only be statically inspected here. The actual Supabase project URL, credentials, deployed function state, migration history, and live clinic rows cannot be verified from this ZIP alone. Do not claim live connectivity until the migration is applied and a Super Admin login successfully loads `platform_admin_dashboard()`.
- Existing clinic completeness is calculated from profile fields returned by the database. Empty contact fields or missing membership/specialties/modules should be reviewed per clinic; this is not a clinical-record completeness certification.

## Required deployment steps
1. Back up the Supabase database.
2. Apply `supabase/migrations/20261025193000_platform_admin_clinic_profile_edit.sql`.
3. Deploy/confirm the `platform-create-clinic` Edge Function and server-side secrets for creating new clinics.
4. Ensure `.env.local` points to the intended Supabase project; never place the service-role key in client-side environment variables.
5. Run `npm ci`, `npm run typecheck`, `npm run build`, then log in as an active platform admin.
6. Test edit/save and verify the updated clinic in the registry; confirm an audit event is written.
