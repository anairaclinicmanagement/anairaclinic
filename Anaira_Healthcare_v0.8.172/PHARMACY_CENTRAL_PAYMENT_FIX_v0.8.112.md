# Anaira Healthcare v0.8.112 — Pharmacy & Central Billing Payment Fix

- Corrected the shared `record_clinic_invoice_payment` RPC permissions so authorised central billing roles can receive payment for pharmacy invoices, while pharmacist role remains limited to pharmacy-only invoices.
- Added invoice visibility/update policies for authorised billing roles and pharmacy-only visibility for pharmacist.
- Improved Billing and Pharmacy payment error messages to show the actual Supabase/Postgres message rather than hiding it behind a generic message.
- Applied the matching migration to the connected Anaira Clinic Supabase project.
- Build/browser end-to-end verification remains pending.
