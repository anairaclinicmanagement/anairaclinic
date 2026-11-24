# Anaira Healthcare v0.8.202 — MFA recovery execution fix

## Root cause addressed
The prior login code only called the server recovery endpoint when the browser-side `listFactors()` returned an unverified factor. If the client response omitted a stale pending factor, the app skipped recovery and attempted `enroll()` again, producing the duplicate-friendly-name error.

## Change
- The server-side recovery endpoint is now called unconditionally before first-time TOTP enrollment.
- The endpoint validates the signed-in user access token.
- It is restricted to the known Anaira Healthcare platform-admin user ID/email.
- It uses the Supabase Auth Admin API with a server-only service/secret key to list factors and delete only the exact named `unverified` TOTP factor.
- Verified factors are not deleted. MFA remains mandatory.

## Required Vercel configuration
Set `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_SECRET_KEY`) from the SAME Supabase project as a server-only Vercel environment variable. Never prefix it with `NEXT_PUBLIC_` and never commit it. Redeploy after setting it.

## Important
This release does not bypass AAL2 or change the Super Admin to password-only. A shared email address does not itself share MFA; factors are scoped to a Supabase Auth user in a specific project.

Static verification only; production build and live login/OTP test remain required.
