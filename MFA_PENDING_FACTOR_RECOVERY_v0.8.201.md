# Anaira Healthcare v0.8.201 — Super Admin MFA Pending-Factor Recovery

## Fix
- Replaces browser-side `auth.mfa.unenroll()` recovery (which may fail for a stale pending factor) with a server-only Supabase Auth Admin MFA deletion endpoint.
- The endpoint authenticates the bearer access token with Supabase Auth.
- It is hard-scoped to the existing Anaira Healthcare platform-admin user ID and email.
- It deletes only TOTP factors with status `unverified` and the exact friendly name `Anaira Healthcare Authenticator`.
- It never deletes verified factors and never disables MFA.
- A fresh TOTP enrollment is created immediately after successful recovery.

## Required Vercel environment variable
Add `SUPABASE_SERVICE_ROLE_KEY` as a server-only Environment Variable for Production (and Preview if used). Use the service-role key from the same Supabase project (`gdyvzvzmybbvufggxjty`). Do not prefix it with `NEXT_PUBLIC_`, do not put it in client code, and do not commit it to Git.

`SUPABASE_SECRET_KEY` is also accepted by the route if the project uses the newer secret-key format.

After adding the variable, redeploy the application.

## Important security behavior
MFA remains mandatory for this Super Admin account. The same email used by another app does not share MFA factors unless that app uses this exact Supabase project and Auth user. This release does not switch the account to password-only access and does not weaken database AAL2 enforcement.

## Verification
Static source checks only. A live Vercel deployment, environment-variable configuration, browser enrollment and OTP verification must still be tested.
