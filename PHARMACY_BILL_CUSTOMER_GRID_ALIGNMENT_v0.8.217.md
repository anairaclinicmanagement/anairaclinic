# Anaira Healthcare v0.8.217 — Bill Customer Grid Alignment

- Moved the Bill customer selector into the previously empty first column of the dispensing modal.
- Desktop first row now places Bill customer, active IPD admission, prescription and payment controls side-by-side.
- Removed the blank left-side space and avoids an unnecessary second row for the customer selector.
- Patient / Named search and dropdown, Cash / Walk-in, payment method and Collect now remain unchanged.
- Tablet/mobile breakpoints continue to stack the customer selector across the available width.
- No database migration or billing/stock logic changes.
- Verification: source-level checks and ZIP integrity only; production build and browser E2E pending.
