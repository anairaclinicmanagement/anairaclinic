# v0.8.143 — Consolidated IPD invoice settlement display

- Consolidated source invoices now display the full covered amount in the Paid column, zero Due, and `SETTLED VIA FINAL IPD BILL` in both Billing patient invoice records and the IPD billing register.
- This is a presentation/accounting relationship only. It does not create a second payment, modify `invoices.paid_amount`, alter payment receipts, or change the final invoice.
- Source invoice remains linked to the final invoice through `consolidated_into_invoice_id`; the final invoice remains the financial record for actual collection.
