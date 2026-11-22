# Admin Settings Routing & Loading Fix — v0.8.186

- Fixed AppShell authorization routing for `hospital_admin`, `clinic_admin`, and `managing_director` role aliases. These management roles now receive the admin route allowlist, including `/settings`, instead of being redirected to `/login`.
- Normalized role names (spaces/hyphens to underscores) before route authorization.
- Admin Settings now resolves the active clinic from the authenticated user's active clinic membership when local active-clinic storage is empty.
- Added explicit loading/error fallback for missing clinic membership and Supabase errors so the page does not remain indefinitely in a loading state.
- No database migration required.
