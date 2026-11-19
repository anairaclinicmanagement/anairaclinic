# Anaira Healthcare v0.8.166 — Billing daily collection export

- Added a date-wise daily collection summary inside Reports & Analytics → Billing & Collection Report.
- Each India-local payment date shows transaction count and collected amount.
- Added a per-day CSV download containing the complete payment rows for that date.
- Existing From date / To date filters continue to scope the report and all downloads.
- Existing full selected-range billing CSV export remains available.
- No database schema or live Supabase data changes.

Verification: static project verification and ZIP integrity only; production build and live payment-data testing were not run.
