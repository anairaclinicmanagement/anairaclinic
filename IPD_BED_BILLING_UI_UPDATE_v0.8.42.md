# Anaira Healthcare v0.8.42 — IPD / Bed / Billing UI update

- Sidebar terminology standardized: OPD, Prescription, and IPD / Bed Management.
- OPD page user-facing Hinglish prompts converted to English where identified.
- Central Billing heading and description now explicitly identify OPD/IPD and diagnostic billing.
- Existing shared billing architecture retained: IPD invoices are stored in `invoices` with `admission_id` and are queried by the central Billing page. The IPD billing RPC is `create_ipd_invoice`; avoid duplicating IPD invoices in a separate billing table.
- Existing room/bed CRUD, 12-hour bed pricing, admission allocation, transfer, discharge and invoice links retained.

## Important integration note
Diagnostic orders currently use `create_reception_diagnostic_bill_discounted` and are linked to a patient. Automatically attaching those diagnostic invoices to an active IPD admission requires a coordinated database RPC change (admission selector + validation + invoice `admission_id` + order workflow). This package does not pretend that patient-only diagnostic billing is already admission-linked. Apply and verify that RPC change against the live Supabase function definition before production use.
