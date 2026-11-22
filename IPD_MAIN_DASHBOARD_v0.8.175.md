# Anaira Healthcare v0.8.175 — IPD Main Dashboard

## Main page improvements
- Added a compact live KPI strip: active admissions, available beds, occupied beds, discharged admissions and outstanding IPD balance.
- Added a sticky section navigation bar: Overview, Ward & Beds, Admissions, Bed Register, Billing, Reports, Clinical Records, Nursing Chart and More.
- Overview now shows only the dashboard/navigation cards and KPIs. Detailed tables and room/bed registers no longer stack below the home page.
- Selecting a section renders only that section inline; it no longer opens a fixed full-screen overlay. This reduces page length and avoids unnecessary scrolling.
- Added a Refresh action to reload clinic-scoped IPD data.
- Retained the six IPD workflow cards and their existing action dispatcher.

## Functional route audit
- All action tokens in the IPD module action map have matching handlers.
- Internal routes referenced by the module action dispatcher exist in the app directory: /laboratory, /operation-theatre, /patients, /pharmacy, /radiology, /settings and /staff.
- Existing admission, bed, transfer, clinical, nursing, discharge, billing and report data flows are retained.

## Verification
- TSX transpilation syntax diagnostics: PASS (0 diagnostics).
- Project static verification: pending final packaging check.
- Full typecheck, production build, live Supabase/browser tests are not certified in this environment.
