# v0.8.149 — Operation Theatre TypeScript clinic ID fix

- Narrow active membership clinic_id into a validated `selectedClinicId: string`.
- Use the validated string for `setActiveClinicId` and all clinic-scoped queries.
- This fixes TS2345 (`string | null` is not assignable to `string`) in OperationTheatreWorkspace.
- No database migration required.
- Static project verification and ZIP integrity are run; production build/typecheck must be run in the user's Windows environment.
