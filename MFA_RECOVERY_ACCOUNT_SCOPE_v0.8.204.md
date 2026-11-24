# Anaira Healthcare v0.8.204 — Account-scoped MFA recovery

## Fix
The previous release called the root Super Admin-only recovery API for every account during MFA enrollment. Clinic accounts consequently received: "This recovery action is not enabled for this account."

Now:
- Only the fixed root Super Admin Auth user ID calls `/api/auth/mfa/recover`.
- Clinic/hospital users do not call that endpoint.
- Clinic/hospital users can remove only their own unverified TOTP factors using their authenticated Supabase session, then enroll a new factor.
- Verified factors are never removed by this path.
- AAL2 enforcement remains enabled; no password-only bypass.

## Database
No new database migration is required. Existing Supabase MFA AAL2 and platform-user protections remain unchanged.

## Verification
Static project verification only. Browser login, production build and OTP E2E remain to be run after deployment.
