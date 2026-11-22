# Admin Settings icon import conflict fix — v0.8.197

- Renamed the `lucide-react` Settings icon import to `SettingsIcon` in `app/settings/page.tsx`.
- Updated the department configuration heading to render `<SettingsIcon />`.
- Kept the page component's local/default export name `Settings` unchanged.
- No database migration required.
