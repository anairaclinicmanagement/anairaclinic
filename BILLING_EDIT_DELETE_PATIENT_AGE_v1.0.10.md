# Anaira Clinic v1.0.10 — Billing edit/void and patient age

- Added invoice-register Edit and Delete/Cancel actions with modal dialogs and required reason fields.
- Only unpaid non-pharmacy invoices can be edited or voided. Paid invoices are blocked from edit/delete to preserve payment reconciliation; pharmacy invoices are blocked from general billing edits to protect stock/GST.
- Applied Supabase `edit_clinic_invoice` RPC in the dedicated Anaira Clinic project. It enforces clinic roles, rejects paid/void/refunded invoices, and writes an audit log.
- OPD new-patient form now accepts age in years as an alternative to DOB; when age is supplied, an approximate DOB is saved. Exact DOB can still be entered.
- Static source checks and ZIP integrity are run; production build/browser E2E must still be tested in the user's environment.
