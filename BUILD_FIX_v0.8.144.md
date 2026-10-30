# v0.8.144 — TypeScript build fix

- Fixed the nullable clinic ID type in OperationTheatreWorkspace clinic membership resolution.
- Validates the active membership clinic_id before passing it to setActiveClinicId.
- No database migration required.

Validation: static project verification; run `npm run typecheck` and `npm run build` in the target Windows environment.
