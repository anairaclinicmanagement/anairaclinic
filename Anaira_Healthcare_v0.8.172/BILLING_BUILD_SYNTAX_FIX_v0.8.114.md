# Billing Build Syntax Fix — v0.8.114

- Fixed malformed JSX expression before the Record Payment modal in `app/billing/page.tsx` (`}{{paymentTarget...` → `}{paymentTarget...`).
- This resolves the reported `Expected a semicolon` / `Expression expected` parser error around line 29.
- TypeScript parser no longer reports syntax errors for `app/billing/page.tsx`.
- Full Next.js build not run: dependencies are not installed in this extracted environment.
