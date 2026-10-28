# v0.8.108 — Reception IPD Diagnostic Billing

- Added OPD / Walk-in versus IPD admission selector to Reception > Billing > Diagnostic Billing.
- IPD billing requires an active admission; bill and all generated diagnostic orders are linked to that admission.
- Supports immediate full payment or issue-now/pay-later workflow.
- IPD tests are released to the relevant lab/radiology worklists while the invoice remains due; OPD diagnostics remain payment-gated.
- Invoice stays in the central invoices register so existing Record Payment and Print actions remain available.
- Includes discount, itemized invoice lines, admission number and audit log.
- Added Supabase migration `20261029100000_ipd_reception_diagnostic_credit_billing.sql`.

Verification note: static project verification and a production build are separate; production build/browser E2E was not run because node_modules are not installed in this environment.
