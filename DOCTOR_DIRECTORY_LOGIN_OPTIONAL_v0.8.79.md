# Doctor Directory & Optional Login — v0.8.79

- Added dedicated `/doctors` page and sidebar navigation.
- Doctor profile data is saved independently from Supabase Auth credentials.
- Profile fields include name, specialty, medical registration number, qualification, experience, staff code, phone, email, room, department, consultation fee, available days/hours, address and notes. Additional profile details are stored in `staff_profiles.metadata`.
- Login creation is optional and can be initiated later from the saved doctor row.
- `clinic-create-staff` now accepts `staff_profile_id` and links the newly created auth user and clinic membership to that existing doctor profile instead of inserting a duplicate profile. Existing staff-login behavior remains for other roles / callers that omit this field.
- Added RLS restrictions so only clinic owners/admins can insert, update or delete staff profiles.

## Deployment
Apply `supabase/migrations/20261028220000_doctor_profile_without_login.sql` to the connected Supabase project and deploy the updated `clinic-create-staff` Edge Function. Then run `npm run build`.

## Verification
Static verification and archive integrity are checked in the packaged source. A live Supabase/production build is not claimed unless executed in an environment with installed dependencies and connected deployment credentials.
