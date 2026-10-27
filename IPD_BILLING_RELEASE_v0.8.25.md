# Anaira Clinic v0.8.25 — Shared IPD Billing

## Changes
- Adds `invoices.admission_id` and a clinic/admission invoice index.
- Adds `create_ipd_invoice(...)` transactional RPC with role validation, admission-to-patient validation, amount/payment method validation, invoice + invoice item + optional full payment, and audit log entry.
- Adds a Create IPD bill dialog on eligible admission rows (owner/admin/receptionist/accountant).
- Adds IPD billing register inside `/ipd`.
- Reception → Billing reads the same `invoices` table and labels admission-linked invoices as IPD.
- Adds an RLS select policy allowing clinic IPD clinical staff to view admission-linked invoices within their clinic.

## Apply before testing
Apply `supabase/migrations/20261025190000_ipd_billing_shared_reception.sql` to the target Supabase project. Take a database backup first.

## Verification status
ZIP integrity and TypeScript TSX syntax parsing are checked. A full dependency install, Next.js production build, Supabase migration execution, and live role-based E2E testing were not run in this environment. This is not a production certification.
