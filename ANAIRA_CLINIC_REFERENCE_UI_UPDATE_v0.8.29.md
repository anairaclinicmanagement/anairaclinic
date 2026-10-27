# Anaira Healthcare v0.8.29 — Reference UI update

## Scope completed in this patch
- Applied Anaira branding and a hospital-style navy/blue visual system based on the supplied reference screenshots; third-party Pehal Grewal Hospital branding is not used in the product.
- Updated shared sidebar, active navigation, header, buttons, cards, form fields, tables, badges, notices, and responsive mobile styling.
- Preserved the existing application routes, Supabase client, role checks, clinic scoping, form handlers, and workflow logic; this patch is a presentation layer and does not replace database workflows.
- Preserved the visible mobile logout control from the existing v0.8.21+ behavior.

## Reference workflows represented in the current source
- OPD: patient lookup/registration, parchi generation and printing, doctor queue/status transitions, consultation notes, and linked lab/pharmacy order processing are present in `app/opd/page.tsx`.
- IPD: room/bed records, admission, admission-note edit, discharge summary, cancellation, and shared billing are present in `app/ipd/page.tsx`.
- Pharmacy, laboratory, radiology, operation theatre, billing, reports, settings and role-based navigation have existing route implementations; their complete live behavior still needs clinic-by-clinic runtime verification.

## Known gaps; do not call the package production-certified yet
- The v0.8.28 audit identified several routes with no direct Supabase operations in the route component, including ambulance, assets, blood bank, clinical quality, CSSD, diet, documents, emergency, hospital services, HR/payroll, insurance, operation theatre, patient portal, procurement, radiology, referrals, sync and telemedicine. Shared components may serve some routes, but each must be runtime-tested.
- IPD source currently documents numbered bed allocation/transfers and nursing charts as separate future workflows. The reference screenshot's full bed-management and nursing-chart coverage is therefore not yet certified as complete.
- Apply `supabase/migrations/20261025193000_platform_admin_clinic_profile_edit.sql` to the configured Supabase project before testing the Super Admin clinic profile Save action.
- No live Supabase project was connected in this environment. This patch does not claim migrations were applied or real patient data was tested.

## Verification still required
1. `npm ci`
2. `npm run typecheck`
3. `npm run build`
4. `npm run verify:static`
5. Test each role against two separate test clinics; verify forbidden reads/writes are rejected.
6. Verify save → reload → persisted value for OPD, IPD, lab, pharmacy, OT, billing, reports and settings using synthetic patients only.
