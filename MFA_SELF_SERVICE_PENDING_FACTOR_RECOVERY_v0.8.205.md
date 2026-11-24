# Anaira Healthcare v0.8.205 — Per-account pending MFA recovery

## Screenshot issue
The Pehal Grewal account reached `enroll()` while an unverified factor with the same friendly name already existed. The previous release used a root-admin-only server endpoint for the root account and a browser unenroll call for clinic users; the browser call did not reliably clear the stale factor.

## Fix
- Every authenticated user calls the same server-side recovery endpoint before a new TOTP enrollment.
- The endpoint validates the bearer token with Supabase Auth and derives the target user ID from that verified token. It accepts no user ID from the browser.
- It uses a server-only Supabase Auth Admin key to inspect that user's factors.
- It deletes only the unverified TOTP factor named `Anaira Healthcare Authenticator` belonging to that same authenticated user.
- It never deletes verified factors or another user's factors.
- After recovery, the login page creates a fresh QR enrollment.
- Existing AAL2 database enforcement remains enabled. No password-only bypass.

## Vercel
`SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_SECRET_KEY`) must be configured as a server-only environment variable for the same Supabase project, then redeploy.

## Verification
Static project verification only. Must still run production build and browser E2E for a clinic account with a pending factor, a root admin account, a verified factor challenge, and tenant-isolation checks.
