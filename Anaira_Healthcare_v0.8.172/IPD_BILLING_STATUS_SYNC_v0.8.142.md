# IPD Billing Status Sync — v0.8.142

- IPD invoice register now fetches `consolidated_into_invoice_id` from the shared invoices table.
- Invoices consolidated into a final IPD invoice display as `INCLUDED IN FINAL IPD BILL`, with zero duplicate due in the IPD register.
- IPD Outstanding report excludes consolidated invoices.
- Daily IPD collection excludes consolidated child invoices to avoid double counting.
- Payment entry remains centralized in Reception → Billing; both screens read the same `invoices.paid_amount` and `status` fields. No payment history is rewritten.

No database migration required; this is a frontend read/display calculation correction.
