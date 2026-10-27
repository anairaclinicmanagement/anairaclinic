# Anaira Healthcare — UI Copy Cleanup v0.8.57

## Changes in this pass
- Removed the Pharmacy screen message that mentioned demo inventory, `.env.local`, raw project URL, and internal clinic identifiers. It now gives an actionable clinic-facing message when no medicines or stock exist.
- Replaced legacy login/dashboard phrases that exposed implementation terms such as Row Level Security, foundation, starter, and expansion points with clinic-facing copy.
- Removed a sentence explicitly saying counts were not demo data.
- Updated legacy module copy to avoid presenting implementation scaffolding as a user-facing product status.
- Updated package version to 0.8.57.

## Audit findings still requiring engineering work
- This is a source-text and UI-copy cleanup, not a complete production certification.
- Supabase connectivity, environment variables, RLS policies, storage permissions, and data correctness cannot be verified without access to the deployed project and its Supabase configuration.
- All clinical and financial workflows still require end-to-end testing with a non-production test clinic, including permissions and audit history.
- The repository includes both Next.js `app/` routes and a legacy Vite `src/` application. Confirm which entry point is deployed; changes to the legacy `src/App.jsx` will not affect Next.js routes unless that legacy app is actually used.
- No real patient data was changed and no Supabase migration was run.
