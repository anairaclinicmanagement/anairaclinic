# OPD Print Banner Root Fix v0.8.96

- Disabled decorative `::before` / `::after` elements on the OPD paper, header, and generated letterhead in both print modes.
- Explicitly set the OPD header inline background to white with no image/shadow.
- Kept plain-A4 clinic branding visible and pre-printed mode branding hidden.
- Preserved the dedicated 3-inch pre-printed spacer.
- No Supabase migration required.

Verification: static project verification and ZIP integrity only. Full Next.js build and browser print rendering were not run in this environment.
