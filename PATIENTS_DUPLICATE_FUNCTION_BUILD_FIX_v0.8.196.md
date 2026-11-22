# Patient directory duplicate function fix — v0.8.196

- Removed the second duplicate `openEdit(PatientRecord)` and `savePatient(React.FormEvent)` implementations from `app/patients/page.tsx`.
- Preserved the first complete edit/save implementations, including patient update validation, clinic scoping, cache update and UI close behavior.
- Scanned project TS/TSX source for repeated named function declarations; no other repeated names were found.
- No database migration required.
- The user's build log also references a stale extracted folder `Anaira_Healthcare_v0.8.172`; remove that old folder from the local project root and clear `.next` before rebuilding.
