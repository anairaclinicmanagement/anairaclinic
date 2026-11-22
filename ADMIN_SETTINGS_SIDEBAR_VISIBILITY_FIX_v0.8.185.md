# Admin Settings Sidebar Visibility Fix — v0.8.185

## Root cause
The Admin Settings navigation item had no module code, but the sidebar visibility filter treated every unclassified link as disabled except Support Centre. As a result, even owner/admin users could not see `/settings` in the workspace sidebar.

## Fix
- Explicitly classify `/settings` as an admin-only navigation item.
- Always show it to clinic `owner` and `admin` roles regardless of enabled module entitlements.
- Recognize equivalent role spellings `hospital_admin`, `clinic_admin`, and `managing_director`.
- Keep it hidden from clinical and operational staff roles.
- Keep existing route and settings page behaviour unchanged.
