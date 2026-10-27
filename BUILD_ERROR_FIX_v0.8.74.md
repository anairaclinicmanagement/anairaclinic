# Anaira Healthcare v0.8.74 — Build Error Fix

Fixed the TypeScript build error in `app/billing/page.tsx` where `membership.clinic_id` could be inferred as `string | null` but was passed to `setActiveClinicId`, which requires a string.

The billing page now validates the membership clinic ID before assigning it or saving it as the active clinic. If the membership record has no valid clinic ID, it shows an actionable message and stops loading billing data.

Verification: `node scripts/verify-project.mjs` passed (35 routes, 55 SQL migrations, 20 required files). A full Next.js build/typecheck was not run in this environment because project dependencies (`node_modules`) are not installed here.
