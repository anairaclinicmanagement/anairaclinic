# IPD unified billing and pharmacy admission link — v0.8.101

- Added admission-scoped charge ledger and auto-numbered advance receipts.
- IPD screen now records bed/room, doctor-round, nursing, procedure, lab, radiology, medicine and other charges with quantity/rate/provider/time.
- Final IPD bill RPC combines pending ledger charges and department invoices linked to the admission; it applies advance receipts oldest-first and records payment allocations.
- Final bill can add calculated 12-hour bed charges from the admission's current bed rate if no bed charge has already been recorded.
- Pharmacy sale form can optionally select an active IPD admission; the RPC validates that patient and admission match and links that invoice to the admission.
- New database tables, policies, indexes and RPCs were applied to Supabase project `gdyvzvzmybbvufggxjty` and queried back to verify presence.

## Important limitations to finish before production
- Doctor rounds, ward nursing, procedures and other non-catalogue services must be entered in the IPD charge ledger; no charge is invented for a clinical action without a configured price.
- Lab invoices created through older/non-admission-aware flows are reconciled by patient and date window at final billing. Staff should select/verify the correct admission for each inpatient diagnostic order.
- Existing old invoices with no `invoice_items` cannot be retroactively reconstructed as detailed charges.
- A production build and signed-in browser end-to-end test were not possible in this workspace because dependencies and a live browser session are not available.
