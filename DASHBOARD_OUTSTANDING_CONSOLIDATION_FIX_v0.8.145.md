# v0.8.145 — Dashboard Outstanding Consolidation Fix

## Root cause
The dashboard invoice query selected only `total_amount` and `paid_amount`, then summed every invoice. It did not select or exclude `consolidated_into_invoice_id`, so the two settled-through-final-IPD source invoices were counted as unpaid.

## Fix
- Select `consolidated_into_invoice_id` and invoice status.
- Exclude consolidated source invoices from dashboard invoice total and outstanding.
- Exclude cancelled/void invoices from those financial totals.
- No payment rows or invoice records are modified.
- No database migration required.

## Supabase verification (NH3 Clinic)
- Raw outstanding across all invoice rows: ₹3,000
- Outstanding excluding consolidated source invoices: ₹0
- Invoice total before excluding consolidated source invoices: ₹2,92,048.10
- Invoice total after excluding consolidated source invoices: ₹2,89,048.10

Static checks are not a substitute for a full production build or browser E2E.
