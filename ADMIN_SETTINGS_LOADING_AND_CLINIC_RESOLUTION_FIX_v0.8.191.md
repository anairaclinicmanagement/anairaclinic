# Admin Settings route and loading fix — v0.8.191

- Admin Settings now resolves the authenticated user's active clinic membership on every page load, validates the locally selected clinic ID, and falls back to a valid membership instead of querying a stale clinic ID.
- Added a 15-second loading timeout, explicit error state, and Reload Settings action so failed Supabase/auth requests do not leave the page appearing permanently hung.
- Existing settings profile, branding, and OPD parchi controls are preserved.
- No database migration required.
- The AppShell route allowlist and Sidebar management-role visibility from v0.8.188 remain in place.
