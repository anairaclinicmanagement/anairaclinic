# Admin Settings Control Center — v0.8.184

## Implemented
- Renamed the management navigation item to **Admin Settings**.
- Added a central department-wise administration hub for OPD, IPD, Pharmacy, Laboratory, Billing, Doctors/Staff, Radiology, OT, Emergency, Blood Bank, Procurement, Assets and Hospital Services.
- Added administration shortcuts for Branches, Reports, Documents, Sync & Recovery and Support.
- Preserved the existing clinic/hospital profile, branding, logo/letterhead/stamp upload and OPD parchi configuration form.
- Existing department records continue to be edited in their owning department workspaces; the central hub routes administrators to those existing workflows rather than duplicating records or writing guessed database schemas.
- Admin Settings navigation is visible to owner/admin management roles under the existing sidebar role filter and `/settings` route allow-list.

## Source audit snapshot
- 36 route directories and 73 SQL migrations in the supplied v0.8.183 source.
- Existing configuration surfaces found: clinic profile and OPD parchi in `/settings`; OPD registration fee/validity and print configuration in `/opd`; Pharmacy store/invoice settings in `/pharmacy`; IPD has a Settings section in its workspace.
- Existing master-data tables include `medications`, `lab_tests`, `services`, `rooms`, `room_beds`, and `staff_profiles`.
- Existing tenant scoping patterns use `clinic_id`; this release does not add new data writes or migrations.

## Important scope boundary
This release adds a central settings hub and routes to department workspaces. It does not claim that every department has a unified CRUD editor inside `/settings`; catalogues and operational records remain managed by their owning module. A full consolidation of every department's create/edit/archive forms into the settings page requires separate module-by-module schema and permission implementation.

## Verification
- `node scripts/verify-project.mjs`: PASS (36 routes, 73 migrations, 21 required files).
- ZIP integrity: checked after packaging.
- Live Supabase, browser E2E, tenant-isolation, production build/typecheck: not run in this environment.
