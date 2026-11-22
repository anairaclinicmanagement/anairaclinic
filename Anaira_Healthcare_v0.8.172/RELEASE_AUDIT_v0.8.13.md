# Anaira Healthcare v0.8.13 — Tenant and Responsive UI Audit

## Implemented
- Added patient salutation (`Mr.`, `Miss`, `Mrs.`, `Ms.`, `Master`, `Dr.`), father name and husband name fields to the new-patient flow on OPD intake.
- OPD print slip now displays patient title and father/husband name when present.
- Added migration `20261025170000_patient_title_father_husband.sql`; it is safe to re-run and adds optional fields without deleting existing patient records.
- Added mobile app-style fixed bottom navigation on small screens; desktop/tablet sidebar navigation remains available.
- Replaced generic promotional sidebar copy with practical Help & Support copy and removed the generic footer slogan.
- Existing OPD/patient/invoice/pharmacy data access remains clinic-scoped in application queries. Database RLS was inspected live for `patients`, `opd_visits`, `invoices`, `invoice_items`, `payments`, `clinic_members`, `staff_profiles`, `medications`, `inventory_batches`, and `clinic_settings`; RLS is enabled on all ten tables and policies exist.

## Tenant isolation note
- Staff membership lookup is scoped to the authenticated user's own `clinic_members` rows; active clinic selection is validated against memberships in AppShell and Sidebar.
- High-risk clinic tables listed above have RLS enabled with clinic-role policies.
- This is a configuration/static audit, not a complete cross-tenant penetration test. Automated authenticated tests with two separate clinic-admin accounts are still required before claiming tenant isolation is fully certified. Super Admin access is intentionally platform-wide.

## Validation
- `node scripts/verify-project.mjs`: PASS (35 routes, 34 migrations).
- TypeScript TSX syntax transpilation: checked for edited files.
- `npm ci --no-audit --no-fund`: timed out in this environment; full `npm run typecheck`, production build, visual device testing, and authenticated cross-tenant E2E were not completed.
