# Anaira Healthcare v0.8.198 — Mandatory MFA

## What changed
- Login now requires email/username/phone + password, followed by Supabase Auth TOTP MFA.
- First login for an account without a verified authenticator forces enrollment using a QR code and manual secret.
- Existing enrolled users must enter a current 6-digit authenticator code on every new AAL1 session.
- Protected app routes (including workspace setup) redirect to the MFA gate unless the session is AAL2 and has a verified TOTP factor.
- Added a database migration that adds restrictive AAL2 policies to every public table and `storage.objects`, converts public views to `security_invoker`, and adds AAL2 checks to public PL/pgSQL `SECURITY DEFINER` RPC functions. Existing tenant/role policies remain in place.

## Deployment order
1. Deploy this application build first.
2. Apply `supabase/migrations/20261124190000_enforce_mfa_aal2_for_authenticated_access.sql` to the same Supabase project.
3. Ask each user to sign in with their existing password and enroll an authenticator app (Google Authenticator, Microsoft Authenticator, Authy or 1Password).
4. Test with one non-admin account and one admin account before rolling out to all users.

## Important
- MFA uses Supabase Auth TOTP; no SMS quota or paid SMS provider is needed.
- Each user must keep access to their authenticator app. Losing it requires an administrator-assisted recovery procedure.
- The migration gates direct PostgREST table and Storage object access at AAL2 and injects an AAL2 check into public PL/pgSQL `SECURITY DEFINER` RPC functions. Trigger functions are excluded because they run as part of an already-authorized table operation.
- The migration intentionally does not delete users, change passwords, or alter clinic memberships.
