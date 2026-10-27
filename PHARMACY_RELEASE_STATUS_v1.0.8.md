# Anaira Healthcare HMS v1.0.8 — Reception Fees, Discounts & Billing

## Implemented
- OPD/reception page: exposed Registration fee & parchi settings button to owner/admin/receptionist; editable default fee and parchi validity saved through existing `set_clinic_opd_policy` RPC.
- Reception diagnostic billing: discount type percentage/fixed amount, discount value, offer/reason, discounted total preview; calls new clinic-scoped `create_reception_diagnostic_bill_discounted` RPC. Latest diagnostic bill summary includes Print bill / Save PDF with patient, test rows, discount, total, paid and due.
- Pharmacy billing: percentage/fixed discount and reason/offer fields; discounted price is applied through new `dispense_pharmacy_sale_discounted` RPC, preserving stock FEFO and audit logging; invoice stores subtotal and discount amount and the printable invoice shows discount.
- Added Supabase migration `20261025145500_reception_diagnostic_discount_billing.sql` and `20261025145600_pharmacy_discounted_sales.sql` to the dedicated Anaira Healthcare project.

## Verification
- `node scripts/verify-project.mjs`: PASS (35 routes, 31 migration files found by static script; remote Supabase migrations applied separately).
- TypeScript TSX transpile syntax checks passed for `app/opd/page.tsx`, `app/billing/page.tsx`, and `app/pharmacy/page.tsx`.
- Full `tsc --noEmit`, Next.js production build, authenticated browser E2E, PDF visual verification and payment reconciliation tests have not been run.

## Important caveat
- Discount wrappers call existing bill creation functions, then apply discount updates in the same SQL transaction. Confirm on staging that the existing diagnostic base function's department release behavior and payment row adjustments match local accounting expectations. GST/legal invoice treatment must be reviewed before live use.
