# Anaira Healthcare v0.8.199 — MFA QR Render Fix

- Fixed TOTP enrollment QR rendering. Supabase Auth `totp.qr_code` is a data URI in supported SDK responses; the previous UI incorrectly wrapped and encoded that data URI a second time.
- The login page now uses an existing `data:` URI unchanged and wraps raw SVG markup only as a fallback.
- No database migration is required for this UI-only fix. The previously applied AAL2 migration remains in place.

Deploy this application update, then sign in and verify that the QR appears.
