# Anaira Clinic v0.8.27 — Super Admin Edit Modal & Save Audit

## Source changes
- Edit clinic form now renders in a fixed viewport overlay with dimmed backdrop, centered responsive panel, and internal scrolling; it no longer pushes the page down.
- Clicking the backdrop closes the modal unless a save is in progress. Close and Cancel remain available.
- The modal shows RPC validation/network/database errors inline so a failed save is visible rather than appearing to do nothing.
- Existing save uses `platform_admin_update_clinic_profile`; the matching migration is included at `supabase/migrations/20261025193000_platform_admin_clinic_profile_edit.sql`.

## Required live database step
Apply that migration to the same Supabase project configured in `.env.local`. If it is not applied, the save call will fail with a missing-function error. This ZIP cannot apply a migration to a remote Supabase project without the user's connected project credentials/session.

## Verification boundary
ZIP archive integrity and source-level delimiter/TSX parse checks should be run locally. No claim is made that remote Supabase connectivity, migration execution, or production runtime was verified from this environment.
