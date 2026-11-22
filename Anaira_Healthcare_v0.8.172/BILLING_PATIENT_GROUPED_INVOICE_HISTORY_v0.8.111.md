# Anaira Healthcare v0.8.111 — Patient-grouped invoice history

- Recent invoices now displays one summary row per patient instead of repeating the patient for every invoice.
- Patient summary aggregates bill count, total billed, total paid, and total due.
- View records opens a patient-specific modal with each individual invoice, payment status, outstanding amount, and date.
- Print remains available for every invoice inside the modal; authorized staff can also record payment, edit eligible unpaid invoices, or cancel eligible unpaid invoices there.
- No database migration was needed; invoices remain individual financial records.
- Validation performed: source/ZIP checks. Browser build and live UI test not run in this environment.
