# Anaira Healthcare v0.8.161

## Staff menu visibility
- Restored the Staff & Role Management (`/staff`) navigation entry for clinic Owner and Admin roles.
- The staff creation/management entry no longer disappears solely because the current subscription plan omits the `staff` or `hr_payroll` module.
- Other staff-related links and HR & Payroll remain governed by their existing entitlements and role permissions.
- The same `visibleLinks` list feeds desktop sidebar and mobile All Menus navigation.

## Department-specific diagnostic catalogue
- Laboratory catalogue popup now lists laboratory-category tests only.
- Radiology / Imaging catalogue popup now lists imaging-category tests only (X-Ray, Ultrasound/USG, CT, MRI, Radiology/Imaging and diagnostic imaging categories such as ECG/Echo).
- Add-test category choices are restricted to the current department.
- Editing an existing legacy category remains possible without silently moving it to another department.
- Existing clinic-scoped catalogue rows and paid diagnostic orders are preserved; no database migration or data rewrite was performed.

## Verification
- `node scripts/verify-project.mjs`: PASS.
- ZIP integrity: PASS.
- `npm run typecheck`: could not complete because project dependencies/types (including React and lucide-react) are not installed in this working environment; resulting module/JSX typing errors are environment-related and not a successful typecheck.
- Production build and live Supabase/browser E2E were not run.
