# IPD Pharmacy Central Billing Sync — v0.8.104

- Added Pharmacy billing register for all invoices containing `invoice_items.item_type = pharmacy`.
- Pharmacy invoices linked to admissions are labelled IPD Pharmacy and retain the existing `admission_id` linkage.
- Added itemized print action for every issued pharmacy invoice, including patient/admission details, totals, paid amount and due amount.
- Added pharmacy-side payment collection through the existing `record_clinic_invoice_payment` RPC, so both Pharmacy and central Billing read the same invoice/payment record.
- Central Billing invoice register labels pharmacy invoices and derives PAID/PARTIAL display from the invoice paid amount. It retains the existing Print and Record Payment actions.
- Static verification passed. Production build, live Supabase payment verification, browser print-preview and E2E tests were not run in this environment.
