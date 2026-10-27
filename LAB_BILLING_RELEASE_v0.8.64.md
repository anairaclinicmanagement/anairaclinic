# Anaira Healthcare v0.8.64 — Laboratory & Central Billing workflow pass

## Changes
- Laboratory worklist supports the role-based lab technician queue, start-test and result entry flow; completed items expose a print-report action.
- Clarified that result entry belongs to the laboratory workspace while charges and collections remain in central Billing & Payments.
- Recent invoice register exposes Print bill actions for OPD/IPD invoices.
- Payment collection supports partial payments against an invoice, uses the existing central invoice-payment RPC, and generates a receipt reference when the operator leaves the reference blank.
- Added A4 print stylesheet to hide navigation/application controls and improve table readability on printed pages.
- Preserved existing Supabase schema and migration history; no destructive reset or data deletion included.

## Verification
- `node scripts/verify-project.mjs`: PASS (35 routes, 52 migrations).
- TypeScript and production build were not run in this environment because dependencies are not installed in the extracted ZIP.
- Live Supabase migration execution and browser end-to-end tests remain to be performed in the target project.

## Important workflow note
The current database payment RPC records collections against an invoice. An independent unallocated patient advance ledger/receipt register and full credit/debit note posting require their own database workflow and must not be represented as implemented merely by invoice partial payments.
