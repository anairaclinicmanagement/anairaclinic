# Anaira Healthcare v0.8.203 — Platform Users clinic-wise listing

## Changes
- Platform Users now returns both platform administrators and clinic memberships, including clinic/hospital name and staff role.
- Users assigned to multiple clinics appear once per clinic membership so the access scope is visible.
- Root Super Admin `techanaira@gmail.com` (fixed user ID in the trusted database migration) is marked ROOT SUPER ADMIN · PROTECTED and receives no disable action in the UI.
- Database RPC also rejects disabling the root Super Admin, so the protection is enforced server-side.
- Clinic membership enable/disable uses a separate audited RPC and does not disable the Auth identity or other clinic memberships.
- MFA AAL2 guard remains required for all management RPCs.

## Supabase
Migration `20261124150000_platform_users_clinic_memberships_and_root_admin_protection.sql` has been applied and verified on Anaira Clinic project.

Verified:
- platform_admin_list_users() exists
- platform_admin_set_user_active(uuid,boolean) exists
- platform_admin_set_clinic_member_active(uuid,boolean) exists
- root Super Admin active row count = 1
- six clinic membership rows present
- MFA guard and root protection verified

## Deploy
Deploy this project version to Vercel to update the UI. Database migration is already applied.
