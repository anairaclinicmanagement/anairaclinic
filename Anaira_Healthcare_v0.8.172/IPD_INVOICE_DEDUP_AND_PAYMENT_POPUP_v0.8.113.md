# Anaira Healthcare v0.8.113 — IPD Invoice Deduplication & Payment Modal

- Added `invoices.consolidated_into_invoice_id` to retain source invoice history while linking bills included in a final IPD invoice.
- Existing source invoices already summarized by final IPD bills are linked, so patient-wise totals exclude their duplicate financial contribution.
- Final IPD billing now avoids adding a second bed charge when a separate IPD bed invoice exists, includes linked department invoices (including diagnostic/lab and bed invoices), and marks source invoices as consolidated.
- Prevents payment collection against a source invoice already consolidated into a final IPD bill.
- Billing's Record Payment UI is a modal with amount, method, reference, cancel/close, and save actions.
- Pharmacy invoice list marks consolidated source invoices and hides duplicate Record Payment actions for them.
- Database migration was applied to the connected Anaira Clinic Supabase project.
- Build/browser E2E test not run because dependencies are not installed in this environment.
