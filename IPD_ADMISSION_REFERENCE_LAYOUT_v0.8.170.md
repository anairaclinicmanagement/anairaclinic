# Anaira Healthcare v0.8.170 — IPD Admission Layout

- Redesigned the IPD New Admission panel to follow the supplied reference layout.
- Added a four-stage visual progress header, patient information section, attendant details, admission/bed allocation section, patient summary sidebar and bed availability summary.
- Kept the existing application sidebar/navigation unchanged.
- Preserved existing admission form state, Supabase save handler, patient selection, bed selection, and existing admission workflow.
- Responsive layout: two-column desktop, stacked mobile.
- No database migration or RLS changes.
- Validation: source-level checks and ZIP integrity; production build not run because dependencies are not bundled.
