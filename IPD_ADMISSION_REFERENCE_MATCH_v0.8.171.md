# Anaira Healthcare v0.8.171 — IPD Admission Reference Match

- Rebuilt the IPD New Admission workspace to closely follow the supplied reference screenshot.
- The admission workspace now occupies the main content area while leaving the application sidebar visible and unchanged.
- Added the hospital / IPD header row, patient quick search, four-step progress strip, three-column patient details form, attendant section, additional information section, patient summary sidebar and bed availability card.
- Added patient demographics as read-only values sourced from the selected registered patient. Patient query now includes the address field.
- Added patient type, priority, mode of arrival, emergency contact and remarks; these additional values are retained in the existing admission notes field to avoid a database migration.
- Preserved the existing Supabase `create_clinic_admission_v2` workflow, physical bed selection, admission record flow, and all other IPD modules.
- Responsive layout is included for smaller screens.
- No database migration or RLS policy changes.
- Static project verification: PASS. Production build could not be completed in this environment because `npm ci` did not finish installing dependencies (`next` executable unavailable).
