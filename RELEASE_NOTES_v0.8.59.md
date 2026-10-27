# Anaira Healthcare Management System v0.8.59

- Removed the non-functional “Help & Support” sidebar promo card.
- Removed the decorative separator line above the sidebar user/profile and powered-by area while preserving logout and brand attribution.
- Updated visible product wording to “Anaira Healthcare” / “Anaira Healthcare Management System” in app screens.
- Added multi-select facility types to Super Admin clinic/hospital creation and editing. A hospital may now be configured with multiple facility types (for example, hospital, diagnostic laboratory, and dental facility) while retaining specialties and enabled modules as separate settings.
- Added migration `20261028120000_multi_facility_types_and_brand_cleanup.sql`; apply it to Supabase before deploying the UI changes.

## Deployment notes

1. Back up the repository and database.
2. Apply the new migration to the target Supabase project.
3. Run `npm install`, `npm run typecheck`, and `npm run build`.
4. Verify Super Admin create/edit flow and confirm `clinics.facility_types` plus `clinic_profile.facility_types` are persisted.
5. Deploy only after the build and authenticated role tests pass.

The live Supabase instance and production browser have not been accessed or tested from this package build.
