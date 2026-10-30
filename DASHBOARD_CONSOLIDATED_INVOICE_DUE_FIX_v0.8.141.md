# Dashboard consolidated invoice due fix — v0.8.141

- Dashboard invoice query now loads `consolidated_into_invoice_id`.
- Dashboard invoice total and outstanding balance exclude invoices consolidated into a final IPD invoice, matching the central Billing page's financial grouping behavior.
- Existing invoice/payment history is not modified.
- Verified Supabase data for NH3 Clinic: the 30-Oct ₹1,500 invoice is already linked to the ₹2,51,500 final invoice; the 29-Oct ₹1,500 invoice is already linked to the ₹2,400 final invoice. Both final invoices retain their recorded payments.
- Nurse / Nursing charge was already included in the original IPD charge category CHECK constraint and UI selector; no database migration is required for that option.
- Static verification passed. Production build, browser E2E and tenant-isolation tests remain outstanding.
