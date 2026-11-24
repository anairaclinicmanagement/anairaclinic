# Anaira Healthcare v0.8.200 — MFA Pending Factor Recovery

## Fix
- Detects existing unverified TOTP factors after password authentication.
- Removes only unverified pending TOTP factors through Supabase Auth `mfa.unenroll`.
- Starts a fresh TOTP enrollment and displays a new QR/manual secret.
- Verified factors are never removed by this recovery path; verified factors continue through the OTP challenge flow.
- No database migration is required. The existing AAL2 enforcement migration remains in place.

## Deploy
1. Extract this ZIP and use the included project folder.
2. Run `npm install` and `npm run build`.
3. Commit and push to the connected deployment branch.
4. After deployment, sign in as the affected user. The stale unverified enrollment is reset and a fresh QR is issued.
5. Scan the new QR and enter its 6-digit code to verify enrollment.

## Verification note
The Supabase project was inspected: `techanaira@gmail.com` had one TOTP factor named `Anaira Healthcare Authenticator` with status `unverified`. This code path specifically recovers that incomplete enrollment. Build was not run in this packaging environment.
